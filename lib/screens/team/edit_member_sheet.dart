import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/section_label.dart';

/// El gerente cambia nombre, cargo, tarifa por hora y rol de una persona.
Future<void> showEditMemberSheet(BuildContext context, Employee employee) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EditMemberSheet(employee: employee),
  );
}

class _EditMemberSheet extends StatefulWidget {
  const _EditMemberSheet({required this.employee});

  final Employee employee;

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  late final _name = TextEditingController(text: widget.employee.name);
  late final _position = TextEditingController();
  late final _rate = TextEditingController(
    text: widget.employee.hourlyRate.round().toString(),
  );
  late UserRole _role = widget.employee.role;
  bool _saving = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _position.text = widget.employee.roleFor(AppScope.of(context).isEnglish);
  }

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    setState(() => _saving = true);
    final ok = await app.updateEmployee(
      employeeId: widget.employee.id,
      fullName: _name.text,
      position: _position.text,
      hourlyRate: double.tryParse(
        _rate.text.trim().replaceAll('.', '').replaceAll(',', '.'),
      ),
      role: _role,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final isMe = widget.employee.id == app.me.id;

    Widget field(
      String label,
      TextEditingController c, {
      TextInputType? keyboard,
      int? maxLength,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow(color: AppColors.muted),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: c,
            keyboardType: keyboard,
            maxLength: maxLength,
            textCapitalization: keyboard == null
                ? TextCapitalization.words
                : TextCapitalization.none,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            style: AppTextStyles.sans(size: 15),
          ),
        ],
      ),
    );

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
                t['editMember'],
                style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              field(t['fullName'], _name, maxLength: 120),
              field(t['position'], _position, maxLength: 60),
              field(t['hourlyRate'], _rate, keyboard: TextInputType.number),
              SectionLabel(t['roleLabel']),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final r in UserRole.values) ...[
                    SelectableChip(
                      label: r == UserRole.manager
                          ? t['manager']
                          : t['employee'],
                      selected: _role == r,
                      // Nadie se cambia su propio rol (protegido también en
                      // el servidor).
                      onTap: isMe ? () {} : () => setState(() => _role = r),
                      expand: true,
                    ),
                    if (r != UserRole.values.last) const SizedBox(width: 6),
                  ],
                ],
              ),
              if (isMe) ...[
                const SizedBox(height: 6),
                Text(
                  t.error('cannot_change_own_role'),
                  style: AppTextStyles.sans(size: 12, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: _saving ? '…' : t['save'],
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
