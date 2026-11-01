import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';

/// Elegir contraseña nueva: al abrir el enlace de recuperación del correo
/// o desde Perfil → Cambiar contraseña ([fromProfile]).
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, this.fromProfile = false});

  final bool fromProfile;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final ok = await app.setNewPassword(_pass.text, _confirm.text);
    if (!mounted || !ok) return;
    _pass.clear();
    _confirm.clear();
    if (widget.fromProfile) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            if (widget.fromProfile) ...[
              const BackPill(),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 30),
            Text(
              t['newPasswordTitle'],
              style: AppTextStyles.sans(
                size: 30,
                weight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 9),
            Text(t['newPasswordSub'], style: AppTextStyles.body()),
            const SizedBox(height: 24),
            _Field(
              label: t['newPassword'],
              controller: _pass,
              hints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            _Field(
              label: t['confirmPassword'],
              controller: _confirm,
              hints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 26),
            PrimaryButton(
              label: app.busy ? '…' : t['savePassword'],
              onPressed: app.busy ? null : _save,
            ),
            if (!widget.fromProfile) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: app.busy ? null : app.cancelPasswordRecovery,
                  child: Text(
                    t['cancel'],
                    style: AppTextStyles.sans(
                      size: 13,
                      color: AppColors.muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final Iterable<String> hints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.eyebrow(color: AppColors.muted),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: hints,
          onSubmitted: onSubmitted,
          style: AppTextStyles.sans(size: 15),
        ),
      ],
    );
  }
}
