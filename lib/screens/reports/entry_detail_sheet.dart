import 'package:flutter/material.dart';

import '../../i18n/formatters.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';
import '../live/fix_entry_sheet.dart';

/// Detalle de un fichaje para el gerente: horas, sitio, corrección, fotos
/// de evidencia y el botón para corregirlo.
Future<void> showEntryDetailSheet(BuildContext context, ReportEntry entry) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EntryDetailSheet(entry: entry),
  );
}

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.entry});

  final ReportEntry entry;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    final e = entry;
    final emp = app.employeeById(e.employeeId);
    final (from, to) = app.reportRange;
    final note = e.correctionNote;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.borderStrong)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emp.name,
                style: AppTextStyles.sans(size: 21, weight: FontWeight.w700),
              ),
              Text(
                '${Fmt.longDate(e.clockInAt, app.lang)} · '
                '${app.siteById(e.siteId)?.name ?? '—'}',
                style: AppTextStyles.body(),
              ),
              const SizedBox(height: 12),
              Text(
                [
                  e.isOpen
                      ? '${Fmt.time(e.clockInAt)}–…'
                      : Fmt.timeRange(e.clockInAt, e.clockOutAt!),
                  AppState.hoursLabel(
                    e.workedWithin(from, to, app.now).inMinutes / 60,
                  ),
                ].join(' · '),
                style: AppTextStyles.mono(size: 18, weight: FontWeight.w700),
              ),
              if (e.clockOutOutside) ...[
                const SizedBox(height: 6),
                Text(
                  t['outsideShort'],
                  style: AppTextStyles.sans(size: 13, color: AppColors.amber),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  t.fmt('correctedNote', {'note': note}),
                  style: AppTextStyles.sans(
                    size: 13,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SectionLabel(t['evidencePhotos']),
              const SizedBox(height: 8),
              FutureBuilder<List<WorkPhoto>>(
                future: app.photosOf(e.id),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final photos = snap.data!;
                  if (photos.isEmpty) {
                    return Text(t['noPhotos'], style: AppTextStyles.body());
                  }
                  return GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    children: [
                      for (final p in photos)
                        _Thumb(
                          photo: p,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _PhotoViewer(photo: p),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              SecondaryButton(
                label: t['fixEntryTitle'],
                onPressed: () {
                  Navigator.of(context).pop();
                  showFixEntrySheet(
                    context,
                    entryId: e.id,
                    employeeId: e.employeeId,
                    clockIn: e.clockInAt,
                    clockOut: e.clockOutAt,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _photoImage(WorkPhoto p, {BoxFit fit = BoxFit.cover}) {
  final bytes = p.bytes;
  if (bytes != null) return Image.memory(bytes, fit: fit);
  final url = p.url;
  if (url == null) {
    return const ColoredBox(
      color: AppColors.cardAlt,
      child: Icon(Icons.broken_image_outlined, color: AppColors.mutedDim),
    );
  }
  return Image.network(
    url,
    fit: fit,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: AppColors.cardAlt,
      child: Icon(Icons.broken_image_outlined, color: AppColors.mutedDim),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, required this.onTap});

  final WorkPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppColors.cardAlt,
        child: InkWell(onTap: onTap, child: _photoImage(photo)),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final WorkPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 5,
                child: _photoImage(photo, fit: BoxFit.contain),
              ),
            ),
            const Positioned(top: 12, left: 12, child: BackPill()),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Text(
                Fmt.time(photo.takenAt),
                textAlign: TextAlign.center,
                style: AppTextStyles.mono(size: 13, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
