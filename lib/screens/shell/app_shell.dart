import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../chat/chat_list_screen.dart';
import '../home/employee_home_screen.dart';
import '../home/manager_home_screen.dart';
import '../login_screen.dart';
import '../more/more_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/my_time_screen.dart';
import '../team/team_screen.dart';
import '../week/week_screen.dart';

class _TabItem {
  const _TabItem(this.label, this.screen);
  final String label;
  final Widget screen;
}

/// Bottom-tab shell. Tabs are stacked in an [IndexedStack] so switching
/// tabs never rebuilds/loses the other tabs' scroll position — pushed
/// screens (clock, chat thread, member detail, ...) go through
/// [Navigator.push] on top of this shell instead.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();

  /// Lets any descendant screen switch the shell's active bottom tab, e.g.
  /// the manager home's "Turnos sin cubrir" card jumping to the Week tab.
  static AppShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  UserRole? _lastRole;

  void goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final isManager = app.role == UserRole.manager;

    // La sesión venció o fue revocada en el servidor: volver al login.
    if (!app.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return const Scaffold();
    }

    // Switching role changes the whole tab set — start back at the first
    // tab instead of keeping a numeric index that now points somewhere
    // unrelated.
    if (_lastRole != null && _lastRole != app.role) {
      _index = 0;
    }
    _lastRole = app.role;

    final tabs = isManager
        ? [
            _TabItem(t['today'], const ManagerHomeScreen()),
            _TabItem(t['shifts'], const WeekScreen()),
            _TabItem(t['team'], const TeamScreen()),
            _TabItem(t['chat'], const ChatListScreen()),
            _TabItem(t['more'], const MoreScreen()),
          ]
        : [
            _TabItem(t['today'], const EmployeeHomeScreen()),
            _TabItem(t['time'], const MyTimeScreen()),
            _TabItem(t['chat'], const ChatListScreen()),
            _TabItem(t['profile'], const ProfileScreen()),
          ];

    final index = _index < tabs.length ? _index : 0;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final tab in tabs) tab.screen],
      ),
      bottomNavigationBar: _BottomBar(
        labels: [for (final tab in tabs) tab.label],
        index: index,
        onChanged: goToTab,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 3,
                          width: 26,
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.lime
                                : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            labels[i].toUpperCase(),
                            style: AppTextStyles.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              letterSpacing: 1,
                              color: i == index
                                  ? AppColors.lime
                                  : AppColors.mutedDim,
                            ),
                          ),
                        ),
                      ],
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
