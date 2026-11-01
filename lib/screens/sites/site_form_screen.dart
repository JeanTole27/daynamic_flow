import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/app_scope.dart';
import '../../state/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/buttons.dart';
import '../../widgets/section_label.dart';

/// Crear o editar un sitio. La forma rápida es estar en la puerta y tocar
/// "Usar mi ubicación actual"; las coordenadas también se pueden escribir.
class SiteFormScreen extends StatefulWidget {
  const SiteFormScreen({super.key, this.site});

  /// null = sitio nuevo.
  final Site? site;

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  late final _name = TextEditingController(text: widget.site?.name);
  late final _address = TextEditingController(text: widget.site?.address);
  late final _lat = TextEditingController(
    text: widget.site == null ? '' : _coord(widget.site!.latitude),
  );
  late final _lng = TextEditingController(
    text: widget.site == null ? '' : _coord(widget.site!.longitude),
  );
  late double _radius = (widget.site?.radiusMeters ?? 100).toDouble();

  bool _locating = false;
  bool _saving = false;

  /// Precisión de la última lectura del GPS, para mostrarla.
  double? _accuracy;

  static String _coord(double v) => v.toStringAsFixed(6);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final fix = await AppScope.of(context).currentLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fix == null) return;
      _lat.text = _coord(fix.latitude);
      _lng.text = _coord(fix.longitude);
      _accuracy = fix.accuracyMeters;
    });
  }

  /// Acepta coma o punto como separador decimal.
  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await AppScope.of(context).saveSite(
      id: widget.site?.id,
      name: _name.text,
      address: _address.text,
      latitude: _parse(_lat.text),
      longitude: _parse(_lng.text),
      radiusMeters: _radius.round(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _toggleActive(Site site) async {
    await AppScope.of(context).setSiteActive(site.id, !site.active);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = app.strings;
    // El sitio puede haber cambiado (p. ej. desactivado) desde que se abrió.
    final site = widget.site == null ? null : app.siteById(widget.site!.id);
    final accuracy = _accuracy;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            const BackPill(),
            const SizedBox(height: 14),
            Text(
              site == null ? t['newSite'] : t['editSite'],
              style: AppTextStyles.sans(
                size: 26,
                weight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 18),
            _Field(
              label: t['siteName'],
              controller: _name,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
            ),
            _Field(
              label: t['siteAddress'],
              controller: _address,
              maxLength: 240,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 6),
            SectionLabel(t['siteLocation']),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SecondaryButton(
                    label: _locating ? t['locating'] : t['useMyLocation'],
                    onPressed: _locating || _saving ? null : _useMyLocation,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accuracy == null
                        ? t['useMyLocationHint']
                        : t.fmt('gpsAccuracy', {'m': accuracy.round()}),
                    style: AppTextStyles.sans(
                      size: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: t['latitude'],
                          controller: _lat,
                          coordinate: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(
                          label: t['longitude'],
                          controller: _lng,
                          coordinate: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: SectionLabel(t['clockRadius'])),
                Text(
                  '${_radius.round()} m',
                  style: AppTextStyles.mono(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            Slider(
              value: _radius,
              min: Site.minRadius.toDouble(),
              max: Site.maxRadius.toDouble(),
              divisions: (Site.maxRadius - Site.minRadius) ~/ 10,
              label: '${_radius.round()} m',
              activeColor: AppColors.primary,
              inactiveColor: AppColors.cardAlt,
              onChanged: _saving ? null : (v) => setState(() => _radius = v),
            ),
            Text(
              t['clockRadiusHint'],
              style: AppTextStyles.sans(size: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _saving ? '…' : t['saveSite'],
              onPressed: _saving || _locating ? null : _save,
            ),
            if (site != null) ...[
              const SizedBox(height: 10),
              if (site.active)
                DangerOutlineButton(
                  label: t['deactivateSite'],
                  onPressed: _saving ? null : () => _toggleActive(site),
                )
              else
                SecondaryButton(
                  label: t['reactivateSite'],
                  onPressed: _saving ? null : () => _toggleActive(site),
                ),
              const SizedBox(height: 8),
              Text(
                t['deactivateSiteHint'],
                style: AppTextStyles.sans(size: 12.5, color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLength,
    this.coordinate = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final int? maxLength;
  final bool coordinate;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: coordinate ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow(color: AppColors.muted),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            maxLength: maxLength,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            textCapitalization: textCapitalization,
            keyboardType: coordinate
                ? const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  )
                : null,
            inputFormatters: coordinate
                ? [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))]
                : null,
            style: coordinate
                ? AppTextStyles.mono(size: 14)
                : AppTextStyles.sans(size: 15),
          ),
        ],
      ),
    );
  }
}
