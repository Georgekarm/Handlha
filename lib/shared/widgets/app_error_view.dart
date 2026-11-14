import 'package:flutter/material.dart';

import '../../app/theme/app_theme_extension.dart';

/// حالة الخطأ / تعذر الاتصال.
class AppErrorView extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? lastSyncLabel;
  final String primaryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AppErrorView({
    super.key,
    this.title = 'النت فصل؟ ولا يهمّك.',
    this.subtitle =
        'مهامك المحفوظة لسه موجودة.\nراجع الاتصال وجرّب تاني لما تكون جاهز.',
    this.lastSyncLabel,
    this.primaryLabel = 'جرّب تاني',
    required this.onRetry,
    this.secondaryLabel = 'شوف المهام المحفوظة',
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isEn = Directionality.of(context) == TextDirection.ltr;

    final effectiveTitle =
        (isEn && title == 'النت فصل؟ ولا يهمّك.')
            ? 'Offline? No worries.'
            : title;
    final effectiveSubtitle = (isEn &&
            subtitle ==
                'مهامك المحفوظة لسه موجودة.\nراجع الاتصال وجرّب تاني لما تكون جاهز.')
        ? 'Your saved tasks are still safe.\nCheck your connection and try again when ready.'
        : subtitle;
    final effectivePrimary =
        (isEn && primaryLabel == 'جرّب تاني') ? 'Try Again' : primaryLabel;
    final effectiveSecondary =
        (isEn && secondaryLabel == 'شوف المهام المحفوظة')
            ? 'View Saved Tasks'
            : secondaryLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.danger, width: 2.2),
                ),
                child: Icon(
                  Icons.priority_high_rounded,
                  color: c.danger,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            effectiveTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            effectiveSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textSecondary,
              height: 1.6,
            ),
          ),
          if (lastSyncLabel != null && lastSyncLabel!.isNotEmpty) ...[
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                lastSyncLabel!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                effectivePrimary,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textOnPrimary,
                ),
              ),
            ),
          ),
          if (effectiveSecondary != null && onSecondary != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onSecondary,
                style: FilledButton.styleFrom(
                  backgroundColor: c.primarySoft,
                  foregroundColor: c.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  effectiveSecondary,
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

