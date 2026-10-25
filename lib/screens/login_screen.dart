import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/buttons.dart';
import 'invite_screen.dart';
import 'shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'carlos@elroble.co');
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _enterAs(UserRole role) {
    final app = AppScope.of(context);
    if (role == UserRole.manager) {
      app.loginAs(UserRole.manager, email: _email.text.trim());
    } else {
      app.loginAs(UserRole.employee, email: 'ana.torres@elroble.co');
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 40, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: AppColors.ink,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'Turnos',
                    style: AppTextStyles.sans(
                      size: 23,
                      weight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 38),
              RichText(
                text: TextSpan(
                  style: AppTextStyles.sans(
                    size: 36,
                    weight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                  children: [
                    TextSpan(text: '${t['loginH1']}\n'),
                    TextSpan(
                      text: t['loginH2'],
                      style: const TextStyle(color: AppColors.lime),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(t['loginSub'], style: AppTextStyles.body()),
              ),
              const SizedBox(height: 30),
              _Field(label: t['email'], controller: _email),
              const SizedBox(height: 12),
              _Field(label: t['password'], controller: _pass, obscure: true),
              const SizedBox(height: 40),
              Text(
                t['enterAs'].toUpperCase(),
                style: AppTextStyles.eyebrow(color: AppColors.mutedDim),
              ),
              const SizedBox(height: 9),
              PrimaryButton(
                label: t['manager'],
                onPressed: () => _enterAs(UserRole.manager),
              ),
              const SizedBox(height: 9),
              SecondaryButton(
                label: t['employee'],
                onPressed: () => _enterAs(UserRole.employee),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InviteScreen()),
                  ),
                  child: Text(
                    t['haveInvite'],
                    style: AppTextStyles.sans(
                      size: 13,
                      color: AppColors.muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;

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
          obscureText: obscure,
          style: AppTextStyles.sans(size: 15),
        ),
      ],
    );
  }
}
