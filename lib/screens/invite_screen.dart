import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/avatar.dart';
import '../widgets/buttons.dart';
import 'shell/app_shell.dart';

/// Aceptar invitación. Con Supabase, el invitado llega autenticado por el
/// enlace del correo (deep link) y aquí solo define su contraseña.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _pass = TextEditingController();
  bool _gpsConsent = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final app = AppScope.of(context);
    final ok = await app.acceptInvite(
      password: _pass.text,
      locationConsent: _gpsConsent,
    );
    if (!mounted || !ok) return;
    _pass.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    // Sin sesión del enlace de invitación no hay a quién activar.
    final linkMissing = !app.isDemo && !app.needsInviteAcceptance;
    // En el demo se muestra un invitado de ejemplo.
    final inviteeName = app.isDemo ? 'Luis Pérez' : app.me.name;
    final inviteeLine = app.isDemo
        ? '${t['cook']} · luis.perez@mail.com'
        : '${app.me.roleFor(app.isEnglish)} · ${app.me.email}';
    final inviteeInitials = app.isDemo ? 'LP' : app.me.initials;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) const BackPill(),
              const SizedBox(height: 22),
              Text(
                t['joinTeam'],
                style: AppTextStyles.sans(
                  size: 30,
                  weight: FontWeight.w700,
                  letterSpacing: -0.5,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 9),
              if (linkMissing) ...[
                Text(
                  t.error('invite_link_required'),
                  style: AppTextStyles.sans(size: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                SecondaryButton(
                  label: t['retry'],
                  onPressed: app.restoreSession,
                ),
              ] else ...[
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.sans(size: 14, color: AppColors.muted),
                    children: [
                      TextSpan(text: '${t['invitedBy']} '),
                      TextSpan(
                        text: app.orgName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: inviteeInitials,
                        paletteIndex: 1,
                        size: 44,
                        fontSize: 14,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inviteeName,
                              style: AppTextStyles.sans(
                                size: 15.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inviteeLine,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.sans(
                                size: 12.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t['createPass'].toUpperCase(),
                  style: AppTextStyles.eyebrow(),
                ),
                const SizedBox(height: 7),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  style: AppTextStyles.sans(size: 15),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: InkWell(
                    onTap: () => setState(() => _gpsConsent = !_gpsConsent),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _gpsConsent
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: _gpsConsent
                                  ? AppColors.primary
                                  : AppColors.borderStrong,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: _gpsConsent
                              ? const Icon(
                                  Icons.check,
                                  size: 11,
                                  color: AppColors.onPrimary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t['gpsConsent'],
                            style: AppTextStyles.sans(
                              size: 11.5,
                              color: AppColors.muted,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: app.busy ? '…' : t['createAccount'],
                  onPressed: app.busy ? null : _accept,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
