import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';

Future<void> showInviteMemberSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _InviteMemberSheet(),
  );
}

class _InviteMemberSheet extends StatefulWidget {
  const _InviteMemberSheet();

  @override
  State<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends State<_InviteMemberSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _position = TextEditingController();
  final _rate = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _position.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final app = AppScope.of(context);
    final rate = double.tryParse(
      _rate.text.replaceAll('.', '').replaceAll(',', '.').trim(),
    );
    setState(() => _sending = true);
    final ok = await app.inviteEmployee(
      name: _name.text,
      email: _email.text,
      position: _position.text,
      hourlyRate: rate ?? double.nan,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppScope.of(context).strings;

    Widget field(
      String label,
      TextEditingController c, {
      TextInputType? keyboard,
      int? maxLength,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboard,
          maxLength: maxLength,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          style: AppTextStyles.sans(size: 15),
        ),
        const SizedBox(height: 12),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderStrong)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['inviteTitle'],
                style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              field(t['fullName'], _name, maxLength: 120),
              field(
                t['email'],
                _email,
                keyboard: TextInputType.emailAddress,
                maxLength: 254,
              ),
              field(t['position'], _position, maxLength: 60),
              field(
                t['hourlyRate'],
                _rate,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                maxLength: 12,
              ),
              const SizedBox(height: 6),
              PrimaryButton(
                label: _sending ? '…' : t['sendInvite'],
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
