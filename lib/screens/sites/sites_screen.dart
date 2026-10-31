import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buttons.dart';
import 'site_form_screen.dart';

/// Lugares donde el equipo ficha. Solo para el gerente.
class SitesScreen extends StatelessWidget {
  const SitesScreen({super.key});

  void _open(BuildContext context, [Site? site]) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SiteFormScreen(site: site)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    // Activos primero; los desactivados quedan al final para el historial.
    final sites = [
      ...app.allSites.where((s) => s.active),
      ...app.allSites.where((s) => !s.active),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Text(
              t['sites'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(t['sitesSub'], style: AppTextStyles.body()),
            const SizedBox(height: 16),
            if (sites.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Text(t['noSitesYet'], style: AppTextStyles.body()),
              ),
            for (final site in sites) ...[
              _SiteRow(site: site, onTap: () => _open(context, site)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
            PrimaryButton(label: t['newSite'], onPressed: () => _open(context)),
          ],
        ),
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.onTap});

  final Site site;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppScope.of(context).strings;
    final address = site.address;
    return Opacity(
      opacity: site.active ? 1 : 0.6,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: site.active ? AppColors.primarySoft : AppColors.cardAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.place_outlined,
                color: site.active ? AppColors.primaryText : AppColors.mutedDim,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          site.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sans(
                            size: 15.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!site.active) ...[
                        const SizedBox(width: 8),
                        Text(
                          t['inactive'].toUpperCase(),
                          style: AppTextStyles.eyebrow(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (address != null && address.isNotEmpty) address,
                      t.fmt('radiusShort', {'m': site.radiusMeters}),
                    ].join(' · '),
                    style: AppTextStyles.sans(size: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.mutedDim,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
