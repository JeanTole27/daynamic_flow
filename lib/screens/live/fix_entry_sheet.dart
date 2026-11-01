import 'package:flutter/material.dart';

import '../../i18n/formatters.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';

/// Elegir cuál de los fichajes de hoy corregir.
Future<void> showPickEntryToFix(BuildContext context) =>
    _sheet(context, const _PickEntrySheet());

/// Corregir la entrada y la salida de un fichaje, con motivo.
Future<void> showFixEntrySheet(
  BuildContext context, {
  required String entryId,
  required String employeeId,
  required DateTime clockIn,
  DateTime? clockOut,
}) => _sheet(
  context,
  _FixEntrySheet(
    entryId: entryId,
    employeeId: employeeId,
    clockIn: clockIn,
    clockOut: clockOut,
  ),
);

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => child,
);

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                  title,
                  style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickEntrySheet extends StatelessWidget {
  const _PickEntrySheet();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final entries = app.fixableEntries;
    return _Frame(
      title: t['fixClock'],
      children: [
        if (entries.isEmpty)
          Text(t['noEntriesToday'], style: AppTextStyles.body())
        else ...[
          Text(t['pickEntryToFix'], style: AppTextStyles.body()),
          const SizedBox(height: 10),
          for (final e in entries) ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              onTap: () {
                Navigator.of(context).pop();
                showFixEntrySheet(
                  context,
                  entryId: e.id,
                  employeeId: e.employeeId,
                  clockIn: e.clockInAt,
                  clockOut: e.clockOutAt,
                );
              },
              child: Row(
                children: [
                  InitialsAvatar(
                    initials: app.employeeById(e.employeeId).initials,
                    paletteIndex: app.employeeById(e.employeeId).avatarIndex,
                    size: 34,
                    fontSize: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.employeeById(e.employeeId).name,
                          style: AppTextStyles.sans(
                            size: 14.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          e.isOpen
                              ? '${Fmt.time(e.clockInAt)}–… · ${t['inProgress']}'
                              : Fmt.timeRange(e.clockInAt, e.clockOutAt!),
                          style: AppTextStyles.mono(
                            size: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.mutedDim,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _FixEntrySheet extends StatefulWidget {
  const _FixEntrySheet({
    required this.entryId,
    required this.employeeId,
    required this.clockIn,
    this.clockOut,
  });

  final String entryId;
  final String employeeId;
  final DateTime clockIn;
  final DateTime? clockOut;

  @override
  State<_FixEntrySheet> createState() => _FixEntrySheetState();
}

class _FixEntrySheetState extends State<_FixEntrySheet> {
  final _note = TextEditingController();
  late TimeOfDay _in = TimeOfDay.fromDateTime(widget.clockIn);
  TimeOfDay? _out;
  bool _saving = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    // Un fichaje abierto se propone cerrar "ahora".
    _out = TimeOfDay.fromDateTime(widget.clockOut ?? AppScope.of(context).now);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _day => DateUtils.dateOnly(widget.clockIn);

  /// Si la salida es anterior a la entrada, es del día siguiente.
  (DateTime, DateTime) get _range {
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _in.hour,
      _in.minute,
    );
    var end = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _out!.hour,
      _out!.minute,
    );
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start, end);
  }

  static String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _in : _out!,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _in = picked : _out = picked);
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final (start, end) = _range;
    setState(() => _saving = true);
    final ok = await app.fixTimeEntry(
      entryId: widget.entryId,
      clockIn: start,
      clockOut: end,
      note: _note.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final emp = app.employeeById(widget.employeeId);
    final (start, end) = _range;
    final presets = [t['fixPresetForgot'], t['fixPresetWrongTime']];

    Widget timeBox(
      String label,
      TimeOfDay value,
      VoidCallback onTap,
    ) => Expanded(
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _saving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.eyebrow(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  _hm(value),
                  style: AppTextStyles.mono(size: 20, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return _Frame(
      title: t['fixEntryTitle'],
      children: [
        Text(
          '${emp.name} · ${Fmt.longDate(widget.clockIn, app.lang)}',
          style: AppTextStyles.sans(size: 14.5, weight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            timeBox(t['csvIn'], _in, () => _pick(start: true)),
            const SizedBox(width: 8),
            timeBox(t['csvOut'], _out!, () => _pick(start: false)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            t.fmt('shiftLength', {'d': lengthLabel(end.difference(start))}),
            if (!DateUtils.isSameDay(start, end)) t['endsNextDay'],
          ].join(' · '),
          style: AppTextStyles.sans(size: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        SectionLabel(t['fixReason']),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in presets)
              SelectableChip(
                label: p,
                selected: _note.text == p,
                onTap: () => setState(() => _note.text = p),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 500,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          style: AppTextStyles.sans(size: 15),
        ),
        const SizedBox(height: 8),
        Text(
          t['fixNotifies'],
          style: AppTextStyles.sans(size: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _saving ? '…' : t['save'],
          onPressed: _saving || _note.text.trim().isEmpty ? null : _save,
        ),
      ],
    );
  }
}

/// "8 h 30 min": duración de un fichaje corregido.
String lengthLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
