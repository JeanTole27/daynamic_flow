import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../state/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/brand_logo.dart';
import '../widgets/buttons.dart';
import '../widgets/chip_button.dart';
import 'invite_screen.dart';
import 'shell/app_shell.dart';

/// Entrada a la app. Primero se elige cómo se va a usar:
///  * Gerente: registra su empresa (o entra si ya tiene cuenta).
///  * Empleado: entra con su cuenta; la primera vez llega por el enlace de
///    invitación, que ya lo deja dentro de la organización del gerente.
///
/// El rol elegido aquí solo cambia el formulario. El rol real sale del
/// perfil en la base de datos.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _org = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  UserRole? _role;
  bool _registering = true;

  /// Correo y empresa del registro que espera confirmación por correo.
  ({String email, String org})? _pendingConfirm;

  @override
  void dispose() {
    _name.dispose();
    _org.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _goToShell() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  /// Modo demo: se elige el rol a mano.
  void _enterAs(UserRole role) {
    AppScope.of(context).loginAs(role);
    _goToShell();
  }

  Future<void> _signIn() async {
    final app = AppScope.of(context);
    final ok = await app.signIn(_email.text, _pass.text);
    if (!mounted) return;
    _pass.clear();
    if (ok) _goToShell();
  }

  Future<void> _signUp() async {
    final app = AppScope.of(context);
    final outcome = await app.signUpManager(
      fullName: _name.text,
      orgName: _org.text,
      email: _email.text,
      password: _pass.text,
    );
    if (!mounted) return;
    switch (outcome) {
      case SignUpOutcome.signedIn:
        _pass.clear();
        _goToShell();
      case SignUpOutcome.confirmEmail:
        _pass.clear();
        setState(() {
          _pendingConfirm = (email: _email.text.trim(), org: _org.text.trim());
        });
      case SignUpOutcome.failed:
        break;
    }
  }

  void _chooseRole(UserRole? role) {
    setState(() {
      _role = role;
      _registering = true;
      _pass.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    // Atrás en un formulario vuelve a elegir el rol en lugar de cerrar la app.
    final inForm = !app.isDemo && (_role != null || _pendingConfirm != null);

    return PopScope(
      canPop: !inForm,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || app.busy) return;
        setState(() => _pendingConfirm = null);
        _chooseRole(null);
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 40, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(height: 38),
                    const SizedBox(width: 12),
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
                        style: const TextStyle(color: AppColors.primaryText),
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
                if (app.isDemo)
                  ..._demo(app)
                else if (_pendingConfirm case final pending?)
                  ..._confirmEmail(app, pending)
                else if (_role == null)
                  ..._rolePicker(app)
                else if (_role == UserRole.manager)
                  ..._managerForm(app)
                else
                  ..._employeeForm(app),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _demo(AppState app) {
    final t = app.strings;
    return [
      Text(
        t['demoMode'].toUpperCase(),
        style: AppTextStyles.eyebrow(color: AppColors.amber),
      ),
      const SizedBox(height: 9),
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
      Center(child: _inviteLink(app)),
    ];
  }

  List<Widget> _rolePicker(AppState app) {
    final t = app.strings;
    return [
      Text(
        t['chooseRole'].toUpperCase(),
        style: AppTextStyles.eyebrow(color: AppColors.mutedDim),
      ),
      const SizedBox(height: 11),
      _RoleCard(
        icon: Icons.storefront_outlined,
        title: t['manager'],
        subtitle: t['managerRoleSub'],
        onTap: () => _chooseRole(UserRole.manager),
      ),
      const SizedBox(height: 10),
      _RoleCard(
        icon: Icons.badge_outlined,
        title: t['employee'],
        subtitle: t['employeeRoleSub'],
        onTap: () => _chooseRole(UserRole.employee),
      ),
    ];
  }

  List<Widget> _managerForm(AppState app) {
    final t = app.strings;
    return [
      _roleHeader(app, t['manager']),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SegmentTab(
              label: t['createAccount'],
              selected: _registering,
              onTap: () => setState(() => _registering = true),
            ),
            SegmentTab(
              label: t['haveAccount'],
              selected: !_registering,
              onTap: () => setState(() => _registering = false),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (_registering) ...[
        _Field(
          label: t['yourName'],
          controller: _name,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _Field(
          label: t['orgNameField'],
          controller: _org,
          autofillHints: const [AutofillHints.organizationName],
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
      ],
      ..._credentials(
        app,
        newPassword: _registering,
        onSubmit: _registering ? _signUp : _signIn,
      ),
      const SizedBox(height: 28),
      PrimaryButton(
        label: app.busy
            ? '…'
            : _registering
            ? t['createAccount']
            : t['signIn'],
        onPressed: app.busy ? null : (_registering ? _signUp : _signIn),
      ),
    ];
  }

  List<Widget> _employeeForm(AppState app) {
    final t = app.strings;
    return [
      _roleHeader(app, t['employee']),
      const SizedBox(height: 20),
      ..._credentials(app, newPassword: false, onSubmit: _signIn),
      const SizedBox(height: 28),
      PrimaryButton(
        label: app.busy ? '…' : t['signIn'],
        onPressed: app.busy ? null : _signIn,
      ),
      const SizedBox(height: 18),
      Text(t['employeeFirstTime'], style: AppTextStyles.body()),
      const SizedBox(height: 4),
      Center(child: _inviteLink(app)),
    ];
  }

  List<Widget> _confirmEmail(
    AppState app,
    ({String email, String org}) pending,
  ) {
    final t = app.strings;
    return [
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              t['confirmEmailTitle'],
              style: AppTextStyles.sans(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              t.fmt('confirmEmailBody', {
                'email': pending.email,
                'org': pending.org,
              }),
              style: AppTextStyles.body(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SecondaryButton(
        label: t['backToSignIn'],
        onPressed: () => setState(() {
          _pendingConfirm = null;
          _registering = false;
        }),
      ),
    ];
  }

  List<Widget> _credentials(
    AppState app, {
    required bool newPassword,
    required VoidCallback onSubmit,
  }) {
    final t = app.strings;
    return [
      _Field(
        label: t['email'],
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 12),
      _Field(
        label: t['password'],
        controller: _pass,
        obscure: true,
        autofillHints: [
          newPassword ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onSubmitted: (_) => onSubmit(),
      ),
    ];
  }

  Widget _roleHeader(AppState app, String roleLabel) {
    return Row(
      children: [
        Text(
          roleLabel.toUpperCase(),
          style: AppTextStyles.eyebrow(color: AppColors.primaryText),
        ),
        const Spacer(),
        TextButton(
          onPressed: app.busy ? null : () => _chooseRole(null),
          child: Text(
            app.strings['changeRole'],
            style: AppTextStyles.sans(
              size: 13,
              color: AppColors.muted,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inviteLink(AppState app) {
    return TextButton(
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const InviteScreen())),
      child: Text(
        app.strings['haveInvite'],
        style: AppTextStyles.sans(
          size: 13,
          color: AppColors.muted,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryText, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.sans(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.body()),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.mutedDim, size: 20),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

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
          autocorrect: !obscure,
          enableSuggestions: !obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          style: AppTextStyles.sans(size: 15),
        ),
      ],
    );
  }
}
