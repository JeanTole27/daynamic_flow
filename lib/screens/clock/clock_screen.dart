import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  Timer? _ticker;
  bool _checkedLocation = false;

  // No se llama a _syncTicker() desde initState: lee AppScope, y un
  // InheritedWidget no se puede consultar antes de que initState termine.
  // build() lo sincroniza en cada reconstrucción.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedLocation) {
      _checkedLocation = true;
      final app = AppScope.of(context);
      // Después del primer frame: checkLocation notifica cambios.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) app.checkLocation();
      });
    }
  }

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
    final status = app.locationStatus;
    final canRetry = !app.isDemo &&
        status != LocationStatus.checking &&
        status != LocationStatus.inside;
    // Salir siempre se permite; entrar solo dentro del sitio.
    final buttonEnabled = !app.clockBusy && (app.clockedIn || gpsOk);

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
                            ? AppColors.primaryText
                            : AppColors.inactive,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      app.clockSinceLabel,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.sans(
                        size: 13.5,
                        color: AppColors.muted,
                      ),
                    ),
                    if (app.clockedIn) ...[
                      const SizedBox(height: 22),
                      const _EvidencePanel(),
                    ],
                  ],
                ),
              ),
              Material(
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: canRetry ? app.checkLocation : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: gpsOk
                                ? AppColors.green
                                : status == LocationStatus.checking
                                ? AppColors.amber
                                : AppColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            app.locationLabel,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.mono(size: 11.5),
                          ),
                        ),
                        if (canRetry) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.refresh,
                            size: 14,
                            color: AppColors.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: buttonEnabled ? app.clockToggle : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: app.clockedIn
                        ? AppColors.red
                        : AppColors.primary,
                    foregroundColor: app.clockedIn
                        ? AppColors.onPrimary
                        : AppColors.onPrimary,
                    disabledBackgroundColor: AppColors.cardAlt,
                    disabledForegroundColor: AppColors.mutedDim,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    app.clockBusy
                        ? '…'
                        : (app.clockedIn ? t['clockOut'] : t['clockIn'])
                              .toUpperCase(),
                    style: AppTextStyles.sans(
                      size: 19,
                      weight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: !buttonEnabled
                          ? AppColors.mutedDim
                          : (app.clockedIn
                                ? AppColors.onPrimary
                                : AppColors.onPrimary),
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

/// Fotos de evidencia del turno en curso.
class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final photos = app.workPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel(t['evidence'])),
            TextButton.icon(
              onPressed: app.uploadingPhoto ? null : app.addWorkPhoto,
              icon: const Icon(
                Icons.photo_camera_outlined,
                size: 16,
                color: AppColors.primaryText,
              ),
              label: Text(
                app.uploadingPhoto ? t['uploading'] : t['addEvidence'],
                style: AppTextStyles.sans(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (photos.isEmpty)
          Text(
            t['evidenceEmpty'],
            style: AppTextStyles.sans(size: 12, color: AppColors.muted),
          )
        else
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _Thumb(photo: photos[i]),
            ),
          ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});

  final WorkPhoto photo;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.bytes;
    final url = photo.url;
    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (url != null) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, color: AppColors.muted),
      );
    } else {
      image = const Icon(Icons.image_outlined, color: AppColors.muted);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        color: AppColors.card,
        child: image,
      ),
    );
  }
}
