import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import 'member_detail_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final rows = app.searchEmployees(_query.text);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(t['team'], style: AppTextStyles.h1())),
                  Material(
                    color: AppColors.lime,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(13),
                      onTap: app.inviteEmployee,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        child: Text(
                          '+ ${t['inviteShort']}',
                          style: AppTextStyles.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: AppTextStyles.sans(size: 14.5),
                decoration: InputDecoration(hintText: t['searchEmp']),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, i) => _EmployeeRow(employee: rows[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    final (label, color) = switch (employee.status) {
      EmployeeStatus.active => (t['active'], AppColors.lime),
      EmployeeStatus.invited => (t['invited'], AppColors.amber),
      EmployeeStatus.inactive => (t['inactive'], AppColors.muted),
    };

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberDetailScreen(employeeId: employee.id),
        ),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: employee.initials,
            paletteIndex: employee.avatarIndex,
            size: 40,
            fontSize: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: AppTextStyles.sans(size: 15, weight: FontWeight.w600),
                ),
                Text(
                  '${employee.roleFor(app.isEnglish)} · ${employee.hoursLabel}',
                  style: AppTextStyles.sans(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.mono(
                size: 9.5,
                letterSpacing: 1,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
