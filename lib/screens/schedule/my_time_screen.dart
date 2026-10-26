import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../i18n/formatters.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/chip_button.dart';
import '../../widgets/lime_switch.dart';

enum _Sub { mine, avail, swaps }

class MyTimeScreen extends StatefulWidget {
  const MyTimeScreen({super.key});

  @override
  State<MyTimeScreen> createState() => _MyTimeScreenState();
}

class _MyTimeScreenState extends State<MyTimeScreen> {
  _Sub _sub = _Sub.mine;

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
            Text(t['myTime'], style: AppTextStyles.h1()),
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
                    label: t['mine'],
                    selected: _sub == _Sub.mine,
                    onTap: () => setState(() => _sub = _Sub.mine),
                  ),
                  SegmentTab(
                    label: t['avail'],
                    selected: _sub == _Sub.avail,
                    onTap: () => setState(() => _sub = _Sub.avail),
                  ),
                  SegmentTab(
                    label: t['swaps'],
                    selected: _sub == _Sub.swaps,
                    onTap: () => setState(() => _sub = _Sub.swaps),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            switch (_sub) {
              _Sub.mine => const _MineTab(),
              _Sub.avail => const _AvailTab(),
              _Sub.swaps => const _SwapsTab(),
            },
          ],
        ),
      ),
    );
  }
}

class _MineTab extends StatelessWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final days = app.dayLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 7; i++) ...[
          _MineRow(
            dd: days[i].toUpperCase(),
            date: app.week.isEmpty ? i + 1 : app.week[i].dayNumber,
            isToday: i == app.todayIndex,
            shift: app.myShiftOn(i),
            weekdayIndex: i,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        AppCard(
          radius: 18,
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['weekTotal'],
                    style: AppTextStyles.sans(
                      size: 13.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.myWeekShiftsLabel,
                    style: AppTextStyles.sans(
                      size: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Text(
                app.myWeekHoursLabel,
                style: AppTextStyles.mono(
                  size: 22,
                  weight: FontWeight.w700,
                  color: AppColors.lime,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MineRow extends StatelessWidget {
  const _MineRow({
    required this.dd,
    required this.date,
    required this.isToday,
    required this.shift,
    required this.weekdayIndex,
  });

  final String dd;
  final int date;
  final bool isToday;
  final Shift? shift;
  final int weekdayIndex;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final shift = this.shift;
    final on = shift != null;
    // Solo turnos que aún no empiezan y que no están ya ofrecidos.
    final canOffer = app.canOfferShift(weekdayIndex);

    final Color bg = isToday
        ? AppColors.lime
        : (on ? AppColors.card : Colors.transparent);
    final Color fg = isToday
        ? AppColors.ink
        : (on ? AppColors.text : AppColors.mutedDim);
    final Color border = isToday
        ? AppColors.lime
        : (on ? AppColors.border : AppColors.borderStrong);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Text(
                  dd,
                  style: AppTextStyles.mono(
                    size: 9.5,
                    letterSpacing: 0.8,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '$date',
                  style: AppTextStyles.mono(
                    size: 19,
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift != null
                      ? Fmt.timeRange(shift.startsAt, shift.endsAt)
                      : t['free'],
                  style: AppTextStyles.mono(
                    size: 15.5,
                    weight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                Text(
                  shift != null
                      ? '${app.me.roleFor(app.isEnglish)} · '
                            '${app.siteById(shift.siteId)?.name ?? ''}'
                      : t['free'],
                  style: AppTextStyles.sans(
                    size: 12,
                    color: fg.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          if (canOffer)
            Material(
              color: AppColors.ink.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
                side: BorderSide(color: AppColors.ink.withValues(alpha: 0.22)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => app.offerShift(weekdayIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Text(
                    t['offer'],
                    style: AppTextStyles.sans(
                      size: 11.5,
                      weight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvailTab extends StatelessWidget {
  const _AvailTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final days = app.dayLabels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t['availIntro'],
          style: AppTextStyles.sans(
            size: 13,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 7; i++) ...[
          AppCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            onTap: () => app.toggleAvailability(i),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      days[i],
                      style: AppTextStyles.sans(
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      app.availability[i]
                          ? '08:00 – 22:00'
                          : (app.isEnglish ? 'Unavailable' : 'No disponible'),
                      style: AppTextStyles.mono(
                        size: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                LimeSwitch(
                  value: app.availability[i],
                  onChanged: (_) => app.toggleAvailability(i),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        PrimaryButton(label: t['save'], onPressed: app.saveAvailability),
      ],
    );
  }
}

class _SwapsTab extends StatelessWidget {
  const _SwapsTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t['swapIntro'],
          style: AppTextStyles.sans(
            size: 13,
            color: AppColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        for (final s in app.swaps) ...[
          _SwapCard(swap: s),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({required this.swap});

  final SwapOffer swap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final emp = app.employeeById(swap.employeeId);
    final isMine = swap.employeeId == app.me.id;
    final statusLabel = switch (swap.status) {
      SwapStatus.open => t['open'],
      SwapStatus.offered => t['offered'],
      SwapStatus.pending => t['pendingSt'],
    };
    final statusColor = switch (swap.status) {
      SwapStatus.open => AppColors.green,
      SwapStatus.offered => AppColors.lime,
      SwapStatus.pending => AppColors.amber,
    };

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(
                initials: emp.initials,
                paletteIndex: emp.avatarIndex,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.swapTitle(swap),
                      style: AppTextStyles.sans(
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      app.swapTimeLabel(swap),
                      style: AppTextStyles.mono(
                        size: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusLabel.toUpperCase(),
                style: AppTextStyles.mono(
                  size: 10.5,
                  weight: FontWeight.w500,
                  letterSpacing: 1,
                  color: statusColor,
                ),
              ),
              if (swap.status == SwapStatus.open && !isMine)
                SizedBox(
                  width: 110,
                  height: 40,
                  child: PrimaryButton(
                    label: t['takeIt'],
                    dense: true,
                    onPressed: () => app.claimSwap(swap.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
