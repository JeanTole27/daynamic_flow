import 'package:flutter/material.dart';

import '../../i18n/formatters.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';

/// El empleado pide un día libre: fecha y motivo opcional.
Future<void> showDayOffSheet(BuildContext context) =>
    _show(context, const _DayOffSheet());

/// El empleado avisa que llegará tarde a su próximo turno.
Future<void> showLateSheet(BuildContext context) =>
    _show(context, const _LateSheet());

Future<void> _show(BuildContext context, Widget sheet) => showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => sheet,
);

/// Marco común de las hojas: asa, título y teclado.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          style: AppTextStyles.sans(size: 15),
        ),
      ],
    );
  }
}

class _DayOffSheet extends StatefulWidget {
  const _DayOffSheet();

  @override
  State<_DayOffSheet> createState() => _DayOffSheetState();
}

class _DayOffSheetState extends State<_DayOffSheet> {
  final _reason = TextEditingController();
  DateTime? _date;
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate(AppState app) async {
    final today = app.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _send(AppState app) async {
    final date = _date;
    if (date == null) return;
    setState(() => _sending = true);
    final ok = await app.requestDayOff(date, _reason.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final date = _date;
    return _SheetFrame(
      title: t['dayOffTitle'],
      children: [
        SectionLabel(t['whichDay']),
        const SizedBox(height: 8),
        Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _sending ? null : () => _pickDate(app),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? '—' : Fmt.longDate(date, app.lang),
                      style: AppTextStyles.sans(
                        size: 16,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.mutedDim,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ReasonField(controller: _reason, label: t['reasonOptional']),
        const SizedBox(height: 12),
        PrimaryButton(
          label: _sending ? '…' : t['sendRequest'],
          onPressed: date == null || _sending ? null : () => _send(app),
        ),
      ],
    );
  }
}

class _LateSheet extends StatefulWidget {
  const _LateSheet();

  @override
  State<_LateSheet> createState() => _LateSheetState();
}

class _LateSheetState extends State<_LateSheet> {
  final _reason = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send(AppState app) async {
    setState(() => _sending = true);
    final ok = await app.notifyLate(_reason.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final shift = app.lateNoticeShift;
    final presets = [t['latePreset10'], t['latePreset30'], t['latePreset60']];
    return _SheetFrame(
      title: t['lateTitle'],
      children: [
        Text(
          shift == null
              ? t['noShiftNext24h']
              : t.fmt('lateShift', {
                  'when':
                      '${app.shortDayLabel(shift.startsAt)} · ${Fmt.timeRange(shift.startsAt, shift.endsAt)}',
                }),
          style: AppTextStyles.sans(
            size: 14.5,
            weight: FontWeight.w600,
            color: shift == null ? AppColors.amber : AppColors.text,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in presets)
              SelectableChip(
                label: p,
                selected: _reason.text == p,
                onTap: () => setState(() => _reason.text = p),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ReasonField(controller: _reason, label: t['reasonOptional']),
        const SizedBox(height: 12),
        PrimaryButton(
          label: _sending ? '…' : t['sendNotice'],
          onPressed: shift == null || _sending ? null : () => _send(app),
        ),
      ],
    );
  }
}
