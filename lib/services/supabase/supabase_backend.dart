import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/models.dart';
import '../auth_service.dart';
import '../backend.dart';
import '../chat_service.dart';
import '../device_services.dart';
import '../notifications_repository.dart';
import '../reports_service.dart';
import '../shifts_repository.dart';
import '../team_repository.dart';
import '../time_clock_service.dart';

/// Implementación de [Backend] sobre Supabase. Toda la autorización la
/// hacen las políticas RLS y las funciones de `supabase/migrations`: este
/// código asume que cualquier llamada puede ser rechazada por el servidor.
Backend supabaseBackend(SupabaseClient client, LocationService location) {
  final ctx = _Ctx(client);
  return Backend(
    auth: _SupabaseAuth(ctx),
    team: _SupabaseTeam(ctx),
    shifts: _SupabaseShifts(ctx),
    clock: _SupabaseClock(ctx),
    chat: _SupabaseChat(ctx),
    notifications: _SupabaseNotifications(ctx),
    reports: _SupabaseReports(ctx),
    location: location,
    changes: ctx.changes,
  );
}

/// Estado compartido por los repositorios: cliente, usuario y organización.
class _Ctx {
  _Ctx(this.client);

  final SupabaseClient client;
  String? _orgId;

  String get uid {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AppException('not_authenticated');
    return id;
  }

  Future<String> orgId() async {
    final cached = _orgId;
    if (cached != null) return cached;
    final id = await guard(() => client.rpc('current_org_id'));
    if (id == null) throw const AppException('not_allowed');
    return _orgId = id as String;
  }

  void clear() => _orgId = null;

  static const _realtimeTables = [
    'shifts',
    'shift_requests',
    'swap_offers',
    'time_entries',
    'chat_messages',
    'notifications',
    'profiles',
  ];

  Stream<String> changes() {
    late final StreamController<String> controller;
    RealtimeChannel? channel;
    controller = StreamController<String>.broadcast(
      onListen: () {
        var c = client.channel('turnos-changes');
        for (final table in _realtimeTables) {
          c = c.onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) => controller.add(table),
          );
        }
        channel = c..subscribe();
      },
      onCancel: () {
        final c = channel;
        if (c != null) client.removeChannel(c);
        channel = null;
      },
    );
    return controller.stream;
  }
}

/// Convierte errores de Supabase en [AppException] con un código estable
/// (sin filtrar mensajes internos a la UI).
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on AppException {
    rethrow;
  } on PostgrestException catch (e) {
    // Las funciones del servidor lanzan `raise exception '<codigo>'` con
    // errcode P0001; el mensaje ES el código.
    if (e.code == 'P0001') {
      throw AppException(e.message, detail: e.details?.toString());
    }
    if (e.code == '23505') throw const AppException('duplicate');
    if (e.code == '23P01') throw const AppException('overlapping_shift');
    if (e.code == '42501') throw const AppException('not_allowed');
    throw const AppException('server_error');
  } on AuthException catch (e) {
    throw AppException(switch (e.code) {
      'invalid_credentials' => 'invalid_credentials',
      'weak_password' => 'weak_password',
      'same_password' => 'weak_password',
      'over_request_rate_limit' => 'rate_limited',
      _ => 'auth_error',
    });
  } on StorageException {
    throw const AppException('upload_failed');
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map ? details['error'] : null;
    throw AppException(code is String ? code : 'server_error');
  } on TimeoutException {
    throw const AppException('network');
  }
}

DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);
String _iso(DateTime d) => d.toUtc().toIso8601String();

Employee _employee(Map<String, dynamic> r) => Employee(
  id: r['id'] as String,
  name: r['full_name'] as String,
  email: r['email'] as String,
  role: r['role'] == 'manager' ? UserRole.manager : UserRole.employee,
  roleEs: r['position_es'] as String? ?? '',
  roleEn: r['position_en'] as String? ?? '',
  hourlyRate: (r['hourly_rate'] as num).toDouble(),
  status: EmployeeStatus.values.byName(r['status'] as String),
  avatarIndex: r['avatar_index'] as int? ?? 0,
);

Shift _shift(Map<String, dynamic> r) => Shift(
  id: r['id'] as String,
  siteId: r['site_id'] as String,
  employeeId: r['employee_id'] as String?,
  startsAt: _date(r['starts_at']),
  endsAt: _date(r['ends_at']),
);

TimeEntry _entry(Map<String, dynamic> r) => TimeEntry(
  id: r['id'] as String,
  employeeId: r['employee_id'] as String,
  siteId: r['site_id'] as String,
  shiftId: r['shift_id'] as String?,
  clockInAt: _date(r['clock_in_at']),
  clockOutAt: _dateOrNull(r['clock_out_at']),
  clockOutOutside: r['clock_out_outside'] as bool? ?? false,
);

// -----------------------------------------------------------------------
// Auth
// -----------------------------------------------------------------------

class _SupabaseAuth implements AuthService {
  _SupabaseAuth(this.ctx);

  final _Ctx ctx;
  GoTrueClient get _auth => ctx.client.auth;

  Future<SessionUser> _loadSessionUser() => guard(() async {
    final row = await ctx.client
        .from('profiles')
        .select('*, organizations(name)')
        .eq('id', ctx.uid)
        .maybeSingle();
    if (row == null) throw const AppException('no_profile');
    final profile = _employee(row);
    if (profile.status == EmployeeStatus.inactive) {
      throw const AppException('account_inactive');
    }
    final org = row['organizations'] as Map<String, dynamic>?;
    return SessionUser(profile: profile, orgName: org?['name'] as String? ?? '');
  });

  @override
  Future<SessionUser?> restoreSession() async {
    if (_auth.currentSession == null) return null;
    try {
      return await _loadSessionUser();
    } on AppException catch (e) {
      // Perfil desactivado o borrado: la sesión guardada ya no sirve.
      if (e.code == 'account_inactive' || e.code == 'no_profile') {
        await signOut();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<SessionUser> signIn({
    required String email,
    required String password,
  }) async {
    await guard(
      () => _auth.signInWithPassword(email: email.trim(), password: password),
    );
    ctx.clear();
    try {
      return await _loadSessionUser();
    } on AppException {
      await signOut();
      rethrow;
    }
  }

  @override
  Future<SessionUser> acceptInvite({required String password}) async {
    if (_auth.currentSession == null) {
      throw const AppException('invite_link_required');
    }
    await guard(() => _auth.updateUser(UserAttributes(password: password)));
    await guard(() => ctx.client.rpc('accept_invite'));
    ctx.clear();
    return _loadSessionUser();
  }

  @override
  Future<void> signOut() async {
    ctx.clear();
    await guard(() => _auth.signOut());
  }
}

// -----------------------------------------------------------------------
// Team
// -----------------------------------------------------------------------

class _SupabaseTeam implements TeamRepository {
  _SupabaseTeam(this.ctx);

  final _Ctx ctx;

  @override
  Future<List<Employee>> fetchTeam() => guard(() async {
    final rows = await ctx.client.from('profiles').select().order('full_name');
    return rows.map(_employee).toList();
  });

  @override
  Future<List<Site>> fetchSites() => guard(() async {
    final rows = await ctx.client
        .from('sites')
        .select()
        .eq('active', true)
        .order('name');
    return [
      for (final r in rows)
        Site(
          id: r['id'] as String,
          name: r['name'] as String,
          address: r['address'] as String?,
          latitude: (r['latitude'] as num).toDouble(),
          longitude: (r['longitude'] as num).toDouble(),
          radiusMeters: r['radius_m'] as int,
        ),
    ];
  });

  @override
  Future<void> inviteEmployee({
    required String name,
    required String email,
    required String positionEs,
    required String positionEn,
    required double hourlyRate,
  }) => guard(() async {
    await ctx.client.functions.invoke(
      'invite-employee',
      body: {
        'full_name': name,
        'email': email,
        'position_es': positionEs,
        'position_en': positionEn,
        'hourly_rate': hourlyRate,
      },
    );
  });

  @override
  Future<void> setEmployeeStatus(String employeeId, EmployeeStatus status) =>
      guard(() async {
        await ctx.client
            .from('profiles')
            .update({'status': status.name})
            .eq('id', employeeId);
      });
}

// -----------------------------------------------------------------------
// Shifts, requests, swaps, availability
// -----------------------------------------------------------------------

class _SupabaseShifts implements ShiftsRepository {
  _SupabaseShifts(this.ctx);

  final _Ctx ctx;

  @override
  Future<List<Shift>> fetchShifts(DateTime from, DateTime to) => guard(() async {
    final rows = await ctx.client
        .from('shifts')
        .select()
        .gte('starts_at', _iso(from))
        .lt('starts_at', _iso(to))
        .order('starts_at');
    return rows.map(_shift).toList();
  });

  @override
  Future<Shift> createShift({
    required String siteId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? employeeId,
  }) => guard(() async {
    final row = await ctx.client
        .from('shifts')
        .insert({
          'org_id': await ctx.orgId(),
          'site_id': siteId,
          'employee_id': employeeId,
          'starts_at': _iso(startsAt),
          'ends_at': _iso(endsAt),
        })
        .select()
        .single();
    return _shift(row);
  });

  @override
  Future<void> assignShift(String shiftId, String employeeId) => guard(() async {
    await ctx.client
        .from('shifts')
        .update({'employee_id': employeeId})
        .eq('id', shiftId);
  });

  @override
  Future<int> duplicatePreviousWeek(DateTime weekStart) => guard(() async {
    final n = await ctx.client.rpc(
      'duplicate_previous_week',
      params: {'p_week_start': _iso(weekStart)},
    );
    return n as int;
  });

  @override
  Future<List<ShiftRequest>> fetchPendingRequests() => guard(() async {
    final rows = await ctx.client
        .from('shift_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        ShiftRequest(
          id: r['id'] as String,
          kind: RequestKind.values.byName(r['kind'] as String),
          employeeId: r['employee_id'] as String,
          shiftId: r['shift_id'] as String?,
          date: DateTime.parse(r['request_date'] as String),
          reason: r['reason'] as String?,
        ),
    ];
  });

  @override
  Future<void> resolveRequest(String requestId, {required bool approve}) =>
      guard(() async {
        await ctx.client.rpc(
          'resolve_request',
          params: {'p_request_id': requestId, 'p_approve': approve},
        );
      });

  @override
  Future<List<SwapOffer>> fetchActiveSwaps() => guard(() async {
    final me = ctx.uid;
    final rows = await ctx.client
        .from('swap_offers')
        .select()
        .inFilter('status', ['open', 'claimed'])
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        SwapOffer(
          id: r['id'] as String,
          employeeId: r['offered_by'] as String,
          shiftId: r['shift_id'] as String,
          claimedBy: r['claimed_by'] as String?,
          requestId: r['request_id'] as String?,
          status: switch (r['status']) {
            'claimed' => SwapStatus.pending,
            _ when r['offered_by'] == me => SwapStatus.offered,
            _ => SwapStatus.open,
          },
        ),
    ];
  });

  @override
  Future<void> offerShift(String shiftId) => guard(() async {
    await ctx.client.rpc('offer_shift', params: {'p_shift_id': shiftId});
  });

  @override
  Future<void> claimSwap(String swapId) => guard(() async {
    await ctx.client.rpc('claim_swap', params: {'p_swap_id': swapId});
  });

  @override
  Future<List<bool>> fetchAvailability(String employeeId) => guard(() async {
    final rows = await ctx.client
        .from('availability')
        .select()
        .eq('employee_id', employeeId);
    final days = List<bool>.filled(7, true);
    for (final r in rows) {
      days[r['weekday'] as int] = r['available'] as bool;
    }
    return days;
  });

  @override
  Future<void> saveAvailability(List<bool> days) => guard(() async {
    final me = ctx.uid;
    await ctx.client.from('availability').upsert([
      for (var i = 0; i < 7; i++)
        {'employee_id': me, 'weekday': i, 'available': days[i]},
    ]);
  });
}

// -----------------------------------------------------------------------
// Time clock + work evidence
// -----------------------------------------------------------------------

class _SupabaseClock implements TimeClockService {
  _SupabaseClock(this.ctx);

  final _Ctx ctx;
  static const _bucket = 'work-evidence';
  static const _signedUrlSeconds = 3600;

  Map<String, dynamic> _fixParams(LocationFix fix) => {
    'p_lat': fix.latitude,
    'p_lng': fix.longitude,
    'p_accuracy_m': fix.accuracyMeters,
    'p_is_mocked': fix.isMocked,
  };

  @override
  Future<TimeEntry?> currentEntry() => guard(() async {
    final row = await ctx.client
        .from('time_entries')
        .select()
        .eq('employee_id', ctx.uid)
        .isFilter('clock_out_at', null)
        .maybeSingle();
    return row == null ? null : _entry(row);
  });

  @override
  Future<TimeEntry> clockIn(LocationFix fix) => guard(() async {
    final row = await ctx.client.rpc('clock_in', params: _fixParams(fix));
    return _entry(row as Map<String, dynamic>);
  });

  @override
  Future<TimeEntry> clockOut(LocationFix fix) => guard(() async {
    final row = await ctx.client.rpc('clock_out', params: _fixParams(fix));
    return _entry(row as Map<String, dynamic>);
  });

  @override
  Future<List<TimeEntry>> fetchEntries(DateTime from, DateTime to) =>
      guard(() async {
        final rows = await ctx.client
            .from('time_entries')
            .select()
            .lt('clock_in_at', _iso(to))
            .or('clock_out_at.is.null,clock_out_at.gt.${_iso(from)}')
            .order('clock_in_at');
        return rows.map(_entry).toList();
      });

  @override
  Future<List<WorkPhoto>> fetchWorkPhotos(String timeEntryId) =>
      guard(() async {
        final rows = await ctx.client
            .from('work_photos')
            .select()
            .eq('time_entry_id', timeEntryId)
            .order('taken_at');
        if (rows.isEmpty) return const [];
        final paths = [for (final r in rows) r['storage_path'] as String];
        final signed = await ctx.client.storage
            .from(_bucket)
            .createSignedUrlsResult(paths, _signedUrlSeconds);
        final urlByPath = {
          for (final s in signed)
            if (s is SignedUrlSuccess) s.path: s.signedUrl,
        };
        return [
          for (final r in rows)
            WorkPhoto(
              id: r['id'] as String,
              timeEntryId: timeEntryId,
              takenAt: _date(r['taken_at']),
              url: urlByPath[r['storage_path']],
            ),
        ];
      });

  @override
  Future<WorkPhoto> uploadWorkPhoto({
    required String timeEntryId,
    required Uint8List jpegBytes,
    LocationFix? fix,
  }) => guard(() async {
    final org = await ctx.orgId();
    final me = ctx.uid;
    // La ruta la fijan las políticas de Storage: <org>/<usuario>/...
    final path =
        '$org/$me/${timeEntryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await ctx.client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      final row = await ctx.client
          .from('work_photos')
          .insert({
            'org_id': org,
            'time_entry_id': timeEntryId,
            'employee_id': me,
            'storage_path': path,
            'latitude': fix?.latitude,
            'longitude': fix?.longitude,
          })
          .select()
          .single();
      final url = await ctx.client.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlSeconds);
      return WorkPhoto(
        id: row['id'] as String,
        timeEntryId: timeEntryId,
        takenAt: _date(row['taken_at']),
        url: url,
      );
    } catch (_) {
      // Sin fila en work_photos el archivo queda huérfano: se borra.
      await ctx.client.storage.from(_bucket).remove([path]);
      rethrow;
    }
  });
}

// -----------------------------------------------------------------------
// Chat
// -----------------------------------------------------------------------

class _SupabaseChat implements ChatService {
  _SupabaseChat(this.ctx);

  final _Ctx ctx;
  static const _pageSize = 200;

  @override
  Future<List<ChatThread>> fetchThreads() => guard(() async {
    final rows = await ctx.client.rpc('chat_overview') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        ChatThread(
          id: r['thread_id'] as String,
          name: r['name'] as String? ?? '',
          isGeneral: r['is_general'] as bool,
          otherEmployeeId: r['other_id'] as String?,
          lastMessage: r['last_body'] as String? ?? '',
          unread: r['unread'] as int? ?? 0,
        ),
    ];
  });

  @override
  Future<List<ChatMessage>> fetchMessages(String threadId) => guard(() async {
    final me = ctx.uid;
    final rows = await ctx.client
        .from('chat_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: false)
        .limit(_pageSize);
    return [
      for (final r in rows.reversed)
        ChatMessage(
          from: r['sender_id'] as String,
          senderId: r['sender_id'] as String,
          text: r['body'] as String,
          fromMe: r['sender_id'] == me,
          sentAt: _date(r['created_at']),
        ),
    ];
  });

  @override
  Future<void> sendMessage({required String threadId, required String text}) =>
      guard(() async {
        await ctx.client.from('chat_messages').insert({
          'thread_id': threadId,
          'sender_id': ctx.uid,
          'body': text,
        });
      });

  @override
  Future<void> markThreadRead(String threadId) => guard(() async {
    await ctx.client.rpc(
      'mark_thread_read',
      params: {'p_thread_id': threadId},
    );
  });

  @override
  Future<String> openDirectThread(String employeeId) => guard(() async {
    final id = await ctx.client.rpc(
      'open_direct_thread',
      params: {'p_other': employeeId},
    );
    return id as String;
  });
}

// -----------------------------------------------------------------------
// Notifications
// -----------------------------------------------------------------------

class _SupabaseNotifications implements NotificationsRepository {
  _SupabaseNotifications(this.ctx);

  final _Ctx ctx;

  @override
  Future<List<AppNotificationItem>> fetchNotifications() => guard(() async {
    final rows = await ctx.client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    return [
      for (final r in rows)
        AppNotificationItem(
          id: r['id'] as String,
          textEs: r['text_es'] as String,
          textEn: r['text_en'] as String,
          createdAt: _date(r['created_at']),
          read: r['read_at'] != null,
        ),
    ];
  });

  @override
  Future<void> markRead(String id) => guard(() async {
    await ctx.client
        .from('notifications')
        .update({'read_at': _iso(DateTime.now())})
        .eq('id', id);
  });

  @override
  Future<void> markAllRead() => guard(() async {
    await ctx.client
        .from('notifications')
        .update({'read_at': _iso(DateTime.now())})
        .eq('profile_id', ctx.uid)
        .isFilter('read_at', null);
  });

  @override
  Future<List<bool>> fetchPrefs() => guard(() async {
    final r = await ctx.client
        .from('notification_prefs')
        .select()
        .eq('profile_id', ctx.uid)
        .maybeSingle();
    if (r == null) return [true, true, false];
    return [
      r['shift_reminder'] as bool,
      r['new_messages'] as bool,
      r['forgot_clock_out'] as bool,
    ];
  });

  @override
  Future<void> savePrefs(List<bool> prefs) => guard(() async {
    await ctx.client.from('notification_prefs').upsert({
      'profile_id': ctx.uid,
      'shift_reminder': prefs[0],
      'new_messages': prefs[1],
      'forgot_clock_out': prefs[2],
    });
  });
}

// -----------------------------------------------------------------------
// Reports
// -----------------------------------------------------------------------

class _SupabaseReports implements ReportsService {
  _SupabaseReports(this.ctx);

  final _Ctx ctx;

  @override
  Future<Map<String, double>> fetchHours(DateTime from, DateTime to) =>
      guard(() async {
        final rows = await ctx.client.rpc(
          'period_hours',
          params: {'p_from': _iso(from), 'p_to': _iso(to)},
        ) as List<dynamic>;
        return {
          for (final r in rows.cast<Map<String, dynamic>>())
            r['employee_id'] as String: (r['hours'] as num).toDouble(),
        };
      });
}
