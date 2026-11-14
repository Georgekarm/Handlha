import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// حالة الفراغ القياسية.
class FeatureEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? primaryCtaLabel;
  final VoidCallback? onPrimaryCta;
  final String? secondaryCtaLabel;
  final VoidCallback? onSecondaryCta;

  const FeatureEmptyState({
    super.key,
    this.icon = Icons.checklist_rounded,
    this.title = 'لسه الصفحة فاضية؟',
    this.subtitle =
        'دي بداية حلوة. اختار حاجة واحدة نفسك تخلّصها، وسيب الباقي خطوة خطوة.',
    this.primaryCtaLabel,
    this.onPrimaryCta,
    this.secondaryCtaLabel,
    this.onSecondaryCta,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 144,
            height: 144,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(
              icon,
              size: 62,
              color: c.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.6,
            ),
          ),
          if (primaryCtaLabel != null && onPrimaryCta != null) ...[
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onPrimaryCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  primaryCtaLabel!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textOnPrimary,
                  ),
                ),
              ),
            ),
          ],
          if (secondaryCtaLabel != null && onSecondaryCta != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onSecondaryCta,
                style: FilledButton.styleFrom(
                  backgroundColor: c.primarySoft,
                  foregroundColor: c.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  secondaryCtaLabel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
