import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/prelaunch_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The team's live notices (a storm watch, an island-wide closure), shown at
/// the top of Home and the map. Nothing when there are none or on an error:
/// a notice is extra, and an outage must not cover the screen.
class NoticeBanner extends ConsumerWidget {
  const NoticeBanner({this.padding = EdgeInsets.zero, super.key});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(liveNoticesProvider).value ?? const [];
    if (notices.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (final n in notices) ...[
            _Notice(notice: n),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = notice.isStorm ? palette.bad : palette.blue;
    final bg = notice.isStorm ? palette.badBg : palette.blueBg;
    final link = notice.linkUrl;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Corners.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Corners.md),
        onTap: link == null
            ? null
            : () => launchUrl(
                Uri.parse(link),
                mode: LaunchMode.externalApplication,
              ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Corners.md),
            border: Border.all(color: fg.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notice.isStorm ? Icons.storm : Icons.campaign_outlined,
                color: fg,
                size: 22,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: AppText.titleSmall.copyWith(color: fg),
                    ),
                    if (notice.body.isNotEmpty)
                      Text(
                        notice.body,
                        style: AppText.bodyMedium.copyWith(color: palette.ink),
                      ),
                    if (link != null)
                      Text(
                        'Tap for the latest',
                        style: AppText.caption.copyWith(
                          color: fg,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
