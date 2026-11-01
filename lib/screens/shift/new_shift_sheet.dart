import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';

/// Crear un turno: persona, día, hora de inicio y fin libres, y sitio.
Future<void> showNewShiftSheet(BuildContext context) => _show(context, null);

/// Editar o cancelar un turno que aún no empieza.
Future<void> showEditShiftSheet(BuildContext context, Shift shift) =>
    _show(context, shift);

Future<void> _show(BuildContext context, Shift? shift) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShiftSheet(shift: shift),
  );
}

class _ShiftSheet extends StatefulWidget {
  const _ShiftSheet({this.shift});

  /// null = turno nuevo.
  final Shift? shift;

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  static const _presets = [
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
  ];

  bool _ready = false;
  late DateTime _weekBase;
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  String? _employeeId;
  String? _siteId;
  bool _saving = false;
  bool _confirmCancel = false;

  bool get _editing => widget.shift != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final app = AppScope.of(context);
    final shift = widget.shift;
    if (shift != null) {
      final d = DateUtils.dateOnly(shift.startsAt);
      _weekBase = d.subtract(Duration(days: d.weekday - 1));
      _day = d;
      _start = TimeOfDay.fromDateTime(shift.startsAt);
      _end = TimeOfDay.fromDateTime(shift.endsAt);
      _employeeId = shift.employeeId;
      _siteId = shift.siteId;
    } else {
      _weekBase = app.weekStart;
      _day = DateUtils.dateOnly(app.today);
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 17, minute: 0);
      final people = app.assignableEmployees;
      _employeeId = people.isEmpty ? null : people.first.id;
      _siteId = app.sites.isEmpty ? null : app.sites.first.id;
    }
  }

  /// Si la hora de fin no es posterior a la de inicio, el turno termina al
  /// día siguiente (p. ej. 22:00–02:00).
  (DateTime, DateTime) get _range {
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _start.hour,
      _start.minute,
    );
    var end = DateTime(_day.year, _day.month, _day.day, _end.hour, _end.minute);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start, end);
  }

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _length(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        // Mover el inicio conserva la duración elegida.
        final length = _range.$2.difference(_range.$1);
        _start = picked;
        _end = TimeOfDay.fromDateTime(_range.$1.add(length));
      } else {
        _end = picked;
      }
    });
  }

  void _setLength(Duration d) {
    setState(() => _end = TimeOfDay.fromDateTime(_range.$1.add(d)));
  }

  Future<void> _save(AppState app) async {
    final (start, end) = _range;
    setState(() => _saving = true);
    final shift = widget.shift;
    final bool ok;
    if (shift == null) {
      final employeeId = _employeeId;
      if (employeeId == null) {
        setState(() => _saving = false);
        return;
      }
      ok = await app.createShift(
        employeeId: employeeId,
        startsAt: start,
        endsAt: end,
        siteId: _siteId,
      );
    } else {
      ok = await app.updateShift(
        shiftId: shift.id,
        employeeId: _employeeId,
        startsAt: start,
        endsAt: end,
        siteId: _siteId ?? shift.siteId,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _cancelShift(AppState app) async {
    setState(() => _saving = true);
    final ok = await app.cancelShift(widget.shift!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final days = app.dayLabels;
    final shift = widget.shift;
    final locked = shift != null && !app.canEditShift(shift);
    final enabled = !locked && !_saving;

    // En edición se muestra también a quien ya tenía el turno, aunque ya no
    // esté entre las personas asignables.
    final people = [
      ...app.assignableEmployees,
      if (_employeeId != null &&
          !app.assignableEmployees.any((e) => e.id == _employeeId))
        app.employeeById(_employeeId!),
    ];
    final sites = [
      ...app.sites,
      if (!app.sites.any((s) => s.id == _siteId)) ?app.siteById(_siteId),
    ];
    final (start, end) = _range;
    final length = end.difference(start);
    final nextDay = !DateUtils.isSameDay(start, end);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.borderStrong)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _editing ? t['editShift'] : t['newShift'],
                  style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
                ),
                if (locked) ...[
                  const SizedBox(height: 8),
                  Text(
                    t['shiftLocked'],
                    style: AppTextStyles.sans(size: 13, color: AppColors.amber),
                  ),
                ],
                const SizedBox(height: 16),
                SectionLabel(t['who']),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in people)
                      SelectableChip(
                        label: p.firstName,
                        selected: _employeeId == p.id,
                        onTap: enabled
                            ? () => setState(() => _employeeId = p.id)
                            : () {},
                      ),
                    if (_editing)
                      SelectableChip(
                        label: t['unassigned'],
                        selected: _employeeId == null,
                        onTap: enabled
                            ? () => setState(() => _employeeId = null)
                            : () {},
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionLabel(t['when']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      SelectableChip(
                        label: days[i].substring(0, 2),
                        selected: DateUtils.isSameDay(
                          _day,
                          _weekBase.add(Duration(days: i)),
                        ),
                        onTap: enabled
                            ? () => setState(
                                () => _day = _weekBase.add(Duration(days: i)),
                              )
                            : () {},
                        mono: true,
                        expand: true,
                      ),
                      if (i != 6) const SizedBox(width: 5),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                SectionLabel(t['shiftTime']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TimeBox(
                        label: t['startTime'],
                        value: _hm(_start),
                        onTap: enabled ? () => _pickTime(start: true) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TimeBox(
                        label: t['endTime'],
                        value: _hm(_end),
                        onTap: enabled ? () => _pickTime(start: false) : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < _presets.length; i++) ...[
                      SelectableChip(
                        label: _length(_presets[i]),
                        selected: length == _presets[i],
                        onTap: enabled ? () => _setLength(_presets[i]) : () {},
                        mono: true,
                        expand: true,
                      ),
                      if (i != _presets.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    t.fmt('shiftLength', {'d': _length(length)}),
                    if (nextDay) t['endsNextDay'],
                  ].join(' · '),
                  style: AppTextStyles.sans(
                    size: 12.5,
                    color: length > AppState.maxShiftLength
                        ? AppColors.red
                        : AppColors.muted,
                  ),
                ),
                if (sites.length > 1) ...[
                  const SizedBox(height: 16),
                  SectionLabel(t['site']),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in sites)
                        SelectableChip(
                          label: s.name,
                          selected: _siteId == s.id,
                          onTap: enabled
                              ? () => setState(() => _siteId = s.id)
                              : () {},
                        ),
                    ],
                  ),
                ],
                if (sites.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    t['noSites'],
                    style: AppTextStyles.sans(size: 12, color: AppColors.red),
                  ),
                ],
                const SizedBox(height: 18),
                if (!locked)
                  PrimaryButton(
                    label: _saving
                        ? '…'
                        : _editing
                        ? t['save']
                        : t['assign'],
                    onPressed:
                        !enabled ||
                            sites.isEmpty ||
                            (!_editing && _employeeId == null)
                        ? null
                        : () => _save(app),
                  ),
                if (_editing && !locked) ...[
                  const SizedBox(height: 10),
                  if (!_confirmCancel)
                    DangerOutlineButton(
                      label: t['cancelShift'],
                      onPressed: enabled
                          ? () => setState(() => _confirmCancel = true)
                          : null,
                    )
                  else ...[
                    Text(
                      switch (shift?.employeeId) {
                        null => t['cancelShiftHintOpen'],
                        final id => t.fmt('cancelShiftHint', {
                          'name': app.employeeById(id).firstName,
                        }),
                      },
                      style: AppTextStyles.sans(
                        size: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: t['keepShift'],
                            onPressed: _saving
                                ? null
                                : () => setState(() => _confirmCancel = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DangerOutlineButton(
                            label: t['confirmCancelShift'],
                            onPressed: _saving ? null : () => _cancelShift(app),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hora de inicio o fin: se toca para abrir el reloj.
class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTextStyles.eyebrow(color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: AppTextStyles.mono(
                        size: 20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.schedule, color: AppColors.mutedDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
