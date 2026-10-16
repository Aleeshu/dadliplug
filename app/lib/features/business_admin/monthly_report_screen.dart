import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The month-end report.
///
/// This is the retention product. A business that cannot see what it got for
/// its money cancels, so the two numbers a renewal is actually argued over —
/// views earned and reviews received — lead, with everything else underneath.
class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(
      monthlyReportProvider((businessId: businessId, monthsBack: 0)),
    );
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Monthly report'),
        backgroundColor: palette.app,
        surfaceTintColor: Colors.transparent,
      ),
      body: reportAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: palette.red),
        ),
        error: (error, _) => _Message(
          icon: Icons.cloud_off_outlined,
          title: 'Could not build your report',
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(
            monthlyReportProvider((businessId: businessId, monthsBack: 0)),
          ),
        ),
        data: (report) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              monthlyReportProvider((businessId: businessId, monthsBack: 0)),
            );
            await ref.read(
              monthlyReportProvider((businessId: businessId, monthsBack: 0))
                  .future,
            );
          },
          child: ListView(
            padding: const EdgeInsets.all(Insets.lg),
            children: [
              Text(
                '${report.label.toUpperCase()} ${report.month.year}',
                style: AppText.sectionLabel,
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Figures for the month to date.',
                style: AppText.bodyMedium.copyWith(color: palette.muted),
              ),
              const SizedBox(height: Insets.lg),

              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      label: 'Advertisement views',
                      value: '${report.adViews}',
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: _BigStat(
                      label: 'Listing views',
                      value: '${report.listingViews}',
                      palette: palette,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  Expanded(
                    child: _BigStat(
                      label: 'Reviews',
                      // Never a fabricated average. No reviews means the month
                      // had none, and that is worth saying plainly.
                      value: report.reviews.total == 0
                          ? '—'
                          : report.reviews.average!.toStringAsFixed(1),
                      caption: report.reviews.total == 0
                          ? 'no reviews this month'
                          : 'average of ${report.reviews.total}',
                      palette: palette,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: _BigStat(
                      label: 'Visits',
                      value: '${report.newVisits}',
                      palette: palette,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Insets.xl),
              Text('REVIEWS THIS MONTH', style: AppText.sectionLabel),
              const SizedBox(height: Insets.sm),
              _StarChart(breakdown: report.reviews, palette: palette),

              const SizedBox(height: Insets.xl),
              Text('ADVERTISEMENTS', style: AppText.sectionLabel),
              const SizedBox(height: Insets.sm),
              if (report.ads.isEmpty)
                Text(
                  'No advertisements ran this month. An advertisement is '
                  'usually the first thing a new subscriber should try.',
                  style: AppText.bodyMedium.copyWith(color: palette.muted),
                )
              else
                for (final ad in report.ads)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _AdRow(
                      ad: ad,
                      maxViews: report.ads.first.views == 0
                          ? 1
                          : report.ads.first.views,
                      palette: palette,
                    ),
                  ),

              const SizedBox(height: Insets.xl),
              Text('CONTACT', style: AppText.sectionLabel),
              const SizedBox(height: Insets.sm),
              _Line(
                icon: Icons.call_outlined,
                label: 'Calls',
                value: '${report.calls}',
                palette: palette,
              ),
              _Line(
                icon: Icons.chat_outlined,
                label: 'WhatsApp taps',
                value: '${report.whatsappTaps}',
                palette: palette,
              ),

              const SizedBox(height: Insets.xl),
              Text(
                'This is also sent to you on WhatsApp at the end of each '
                'month, so you do not need to remember to open it.',
                style: AppText.caption.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.palette,
    this.caption,
  });

  final String label;
  final String value;
  final AppPalette palette;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppText.numericLarge.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            label,
            style: AppText.caption.copyWith(color: palette.muted),
          ),
          if (caption != null)
            Text(
              caption!,
              style: AppText.caption.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }
}

/// One bar per star rating.
///
/// Shows all five rows even when they are zero. A chart that omits the empty
/// stars makes a single five star review look like a perfect record.
class _StarChart extends StatelessWidget {
  const _StarChart({required this.breakdown, required this.palette});

  final StarBreakdown breakdown;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final max = [
      breakdown.oneStar,
      breakdown.twoStar,
      breakdown.threeStar,
      breakdown.fourStar,
      breakdown.fiveStar,
    ].fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          for (var stars = 5; stars >= 1; stars--)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      stars == 1 ? '1 star' : '$stars stars',
                      style: AppText.caption.copyWith(color: palette.muted),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Corners.sm),
                      child: LinearProgressIndicator(
                        // Zero total must not divide by zero, and a bar of
                        // zero width is exactly right for no reviews.
                        value: max == 0 ? 0 : breakdown.countFor(stars) / max,
                        minHeight: 8,
                        backgroundColor: palette.line,
                        valueColor: AlwaysStoppedAnimation(palette.gold),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${breakdown.countFor(stars)}',
                      textAlign: TextAlign.end,
                      style: AppText.caption.copyWith(color: palette.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AdRow extends StatelessWidget {
  const _AdRow({
    required this.ad,
    required this.maxViews,
    required this.palette,
  });

  final AdPerformance ad;
  final int maxViews;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Corners.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ad.title,
                  style: AppText.titleMedium.copyWith(color: palette.ink),
                ),
              ),
              Text(
                '${ad.views}',
                style: AppText.numeric.copyWith(color: palette.ink),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Corners.sm),
            child: LinearProgressIndicator(
              value: ad.views / maxViews,
              minHeight: 6,
              backgroundColor: palette.line,
              valueColor: AlwaysStoppedAnimation(palette.red),
            ),
          ),
          if (ad.redemptions > 0) ...[
            const SizedBox(height: Insets.xs),
            Text(
              '${ad.redemptions} redeemed at the till',
              style: AppText.caption.copyWith(color: palette.good),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: palette.muted),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              label,
              style: AppText.bodyMedium.copyWith(color: palette.ink),
            ),
          ),
          Text(value, style: AppText.numeric.copyWith(color: palette.ink)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Icon(icon, size: 44, color: palette.muted),
        const SizedBox(height: Insets.lg),
        Center(
          child: Text(
            title,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium.copyWith(color: palette.muted),
            ),
          ),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: Insets.lg),
          Center(
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
