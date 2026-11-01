import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          children: [
            Row(
              children: [
                Expanded(child: Text(t['chat'], style: AppTextStyles.h1())),
                TextButton.icon(
                  onPressed: () => _newMessage(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    t['newMessage'],
                    style: AppTextStyles.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final thread in app.threads) ...[
              _ThreadRow(thread: thread),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// Elegir con quién hablar: gerente o compañeros activos.
Future<void> _newMessage(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final app = AppScope.of(sheetContext);
      final t = app.strings;
      final people =
          app.activeEmployees.where((e) => e.id != app.me.id).toList()
            ..sort((a, b) {
              // Primero los gerentes.
              if (a.role != b.role) return a.role == UserRole.manager ? -1 : 1;
              return a.name.compareTo(b.name);
            });
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: AppColors.borderStrong)),
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            children: [
              Text(
                t['newMessage'],
                style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (people.isEmpty)
                Text(t['noOneToMessage'], style: AppTextStyles.body()),
              for (final p in people) ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                  onTap: () async {
                    final navigator = Navigator.of(sheetContext);
                    final id = await app.openDirectThreadWith(p.id);
                    navigator.pop();
                    if (id == null) return;
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(threadKey: id, title: p.name),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: p.initials,
                        paletteIndex: p.avatarIndex,
                        size: 36,
                        fontSize: 12,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: AppTextStyles.sans(
                                size: 14.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.roleFor(app.isEnglish),
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
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final name = app.threadTitle(thread);
    final last = thread.lastMessage;
    final unread = thread.unread;
    final isGeneral = thread.isGeneral;

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(threadKey: thread.id, title: name),
        ),
      ),
      child: Row(
        children: [
          isGeneral
              ? Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '#',
                    style: AppTextStyles.mono(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                )
              : InitialsAvatar(
                  initials: app.threadInitials(thread),
                  paletteIndex: app.threadAvatarIndex(thread),
                  size: 40,
                  fontSize: 13,
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.sans(size: 14.5, weight: FontWeight.w600)),
                Text(
                  last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sans(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$unread',
                style: AppTextStyles.mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

}
