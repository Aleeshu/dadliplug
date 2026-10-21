import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// The contact line the legal pages end with. Comes from SUPPORT_EMAIL, so
/// the same files serve the app and the public web pages.
String legalContact() => AppConfig.supportEmail.isEmpty
    ? 'Use "Report wrong info" on any listing, or message the Dadliplug team '
          'on WhatsApp.'
    : 'Email ${AppConfig.supportEmail}.';

/// One block of the small Markdown subset the legal pages use.
sealed class LegalBlock {
  const LegalBlock(this.text);
  final String text;
}

class LegalHeading extends LegalBlock {
  const LegalHeading(super.text, {required this.level});
  final int level;
}

class LegalBullet extends LegalBlock {
  const LegalBullet(super.text, {this.number});

  /// Set for "1." items, null for "-" items.
  final int? number;
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(super.text);
}

/// Parses headings (#, ##, ###), "-" and "1." list items, and paragraphs.
/// Deliberately tiny: the legal files are ours, and a Markdown package for
/// three pages would be a dependency to keep up to date for nothing.
List<LegalBlock> parseLegal(String source, {required String contact}) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];
  void flush() {
    if (paragraph.isNotEmpty) {
      blocks.add(LegalParagraph(paragraph.join(' ')));
      paragraph.clear();
    }
  }

  for (final raw in source.replaceAll('{{CONTACT}}', contact).split('\n')) {
    final line = raw.trimRight();
    final heading = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
    final bullet = RegExp(r'^- (.*)$').firstMatch(line);
    final numbered = RegExp(r'^(\d+)\. (.*)$').firstMatch(line);
    if (line.trim().isEmpty) {
      flush();
    } else if (heading != null) {
      flush();
      blocks.add(
        LegalHeading(heading.group(2)!, level: heading.group(1)!.length),
      );
    } else if (bullet != null) {
      flush();
      blocks.add(LegalBullet(bullet.group(1)!));
    } else if (numbered != null) {
      flush();
      blocks.add(
        LegalBullet(numbered.group(2)!, number: int.parse(numbered.group(1)!)),
      );
    } else {
      paragraph.add(line.trim());
    }
  }
  flush();
  return blocks;
}

/// "**bold** rest" as spans.
List<TextSpan> _inline(String text, TextStyle bold) => [
  for (final (i, part) in text.split('**').indexed)
    TextSpan(text: part, style: i.isOdd ? bold : null),
];

/// A legal page from assets/legal, readable offline.
class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.asset, required this.title, super.key});

  final String asset;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = AppText.bodyMedium.copyWith(color: palette.ink, height: 1.45);
    final bold = body.copyWith(fontWeight: FontWeight.w700);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(title: Text(title), backgroundColor: palette.app),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snap) {
          final source = snap.data;
          if (source == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocks = parseLegal(source, contact: legalContact());
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Insets.huge,
                0,
                Insets.huge,
                Insets.giant,
              ),
              children: [
                for (final b in blocks)
                  switch (b) {
                    // The page title is already in the app bar.
                    LegalHeading(level: 1) => const SizedBox.shrink(),
                    LegalHeading(:final text, :final level) => Padding(
                      padding: const EdgeInsets.only(
                        top: Insets.lg,
                        bottom: Insets.xs,
                      ),
                      child: Text(
                        text,
                        style:
                            (level == 2
                                    ? AppText.titleMedium
                                    : AppText.titleSmall)
                                .copyWith(color: palette.ink),
                      ),
                    ),
                    LegalBullet(:final text, :final number) => Padding(
                      padding: const EdgeInsets.only(bottom: Insets.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              number == null ? '•' : '$number.',
                              style: body,
                            ),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: _inline(text, bold)),
                              style: body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LegalParagraph(:final text) => Padding(
                      padding: const EdgeInsets.only(bottom: Insets.sm),
                      child: Text.rich(
                        TextSpan(children: _inline(text, bold)),
                        style: body,
                      ),
                    ),
                  },
              ],
            ),
          );
        },
      ),
    );
  }
}

/// About: version, legal pages, contact, photo credits and licences.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Kept in step with pubspec.yaml by hand; shown to support, not logic.
  static const version = '0.1.0';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = AppText.bodyMedium.copyWith(color: palette.muted);

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(title: const Text('About'), backgroundColor: palette.app),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          Text(
            AppConfig.appName,
            style: AppText.displayMedium.copyWith(color: palette.ink),
          ),
          Text('Plug into local. Version $version', style: muted),
          const SizedBox(height: Insets.lg),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of use'),
            onTap: () => context.push('/terms'),
          ),
          if (AppConfig.supportEmail.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Contact the Dadliplug team'),
              subtitle: const Text(AppConfig.supportEmail),
              onTap: () => launchUrl(
                Uri(
                  scheme: 'mailto',
                  path: AppConfig.supportEmail,
                  query: 'subject=Dadliplug',
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: version,
            ),
          ),
          const Divider(height: Insets.xxl),
          Text(
            'Photo credits',
            style: AppText.titleSmall.copyWith(color: palette.ink),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            "Home banner: Shirley's Heights over English Harbour, by Dr. "
            'Thomas Liptak, CC BY 4.0, via Wikimedia Commons. Photos on demo '
            'listings, offers and events are from Wikimedia Commons and are '
            'credited where they appear.',
            style: muted,
          ),
        ],
      ),
    );
  }
}
