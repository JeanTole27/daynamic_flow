import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Timer? _ticker;

  // No se llama a _syncTicker() desde initState: lee AppScope, y un
  // InheritedWidget no se puede consultar antes de que initState termine.
  // build() lo sincroniza en cada reconstrucción.

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final clockedIn = AppScope.of(context).clockedIn;
    if (clockedIn && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!clockedIn && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    _syncTicker();

    final gpsOk = app.insideAllowedRadius;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const BackPill(),
                  const SizedBox(width: 12),
                  Text(
                    t['clockTitle'],
                    style: AppTextStyles.sans(
                      size: 17,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (app.clockedIn ? t['working'] : t['notWorking'])
                          .toUpperCase(),
                      style: AppTextStyles.eyebrow(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppState.formatElapsed(app.elapsed),
                      style: AppTextStyles.mono(
                        size: 62,
                        weight: FontWeight.w700,
                        letterSpacing: -2,
                        color: app.clockedIn
                            ? AppColors.lime
                            : const Color(0xFF3A3F36),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      app.clockedIn ? t['sinceNine'] : t['beforeIn'],
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sans(
                        size: 13.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: gpsOk ? AppColors.green : AppColors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      gpsOk ? t['inRadius'] : t['outRadius'],
                      style: AppTextStyles.mono(size: 11.5),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: app.clockToggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !gpsOk
                        ? const Color(0xFF1F241C)
                        : (app.clockedIn ? AppColors.red : AppColors.lime),
                    foregroundColor: !gpsOk
                        ? const Color(0xFF5C6357)
                        : (app.clockedIn
                              ? const Color(0xFF1A0703)
                              : AppColors.ink),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    (app.clockedIn ? t['clockOut'] : t['clockIn'])
                        .toUpperCase(),
                    style: AppTextStyles.sans(
                      size: 19,
                      weight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t['clockFoot'],
                textAlign: TextAlign.center,
                style: AppTextStyles.sans(
                  size: 11.5,
                  color: AppColors.mutedDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
