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
            Text(t['chat'], style: AppTextStyles.h1()),
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
                      color: AppColors.lime,
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
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$unread',
                style: AppTextStyles.mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

}
