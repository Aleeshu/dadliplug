import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/listing/listing_screen.dart'
    show singleBusinessProvider;
import 'package:antigua_business_map/features/map/island_ads_map.dart';
import 'package:antigua_business_map/models/business.dart';
import 'package:antigua_business_map/models/business_category.dart';
import 'package:antigua_business_map/services/map_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Whether a point is on Antigua or Barbuda, generously. A pin dropped in the
/// sea, or on another island, is a slip of the thumb.
bool isOnTheIslands(double latitude, double longitude) =>
    latitude >= 16.9 &&
    latitude <= 17.8 &&
    longitude >= -62.0 &&
    longitude <= -61.6;

/// Move the map pin and choose its photo (plan.md section 3, Phase 7).
///
/// Basic and Featured only, plus trials. A Growing listing sees why, and a
/// way to ask the team to move it: the database refuses the change anyway.
class PinEditorScreen extends ConsumerStatefulWidget {
  const PinEditorScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<PinEditorScreen> createState() => _PinEditorScreenState();
}

class _PinEditorScreenState extends ConsumerState<PinEditorScreen> {
  ({double latitude, double longitude})? _at;
  String? _photo;
  bool _photoTouched = false;
  bool _busy = false;

  Future<void> _save(Business b) async {
    final at = _at;
    if (at != null && !isOnTheIslands(at.latitude, at.longitude)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is off Antigua and Barbuda. Drop the pin again.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client
          .from('businesses')
          .update({
            if (at != null) 'latitude': at.latitude,
            if (at != null) 'longitude': at.longitude,
            if (_photoTouched) 'pin_image_url': _photo,
          })
          .eq('id', b.id);
      ref
        ..invalidate(singleBusinessProvider(b.id))
        ..invalidate(businessListProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pin saved.')));
        Navigator.of(context).maybePop();
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your signal.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final business = ref.watch(singleBusinessProvider(widget.businessId));

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Your map pin'),
        backgroundColor: palette.app,
      ),
      body: business.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) =>
            const Center(child: Text('Could not load the listing.')),
        data: (b) {
          if (b == null) {
            return const Center(child: Text('Listing not found.'));
          }
          return b.canCustomisePin ? _editor(b, palette) : _locked(b, palette);
        },
      ),
    );
  }

  Widget _locked(Business b, AppPalette palette) => Padding(
    padding: const EdgeInsets.all(Insets.huge),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.push_pin_outlined, size: 40, color: palette.muted),
        const SizedBox(height: Insets.md),
        Text(
          'Moving your pin is part of Growth and Premium',
          style: AppText.titleLarge.copyWith(color: palette.ink),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'On Starter the team places your pin and moves it whenever you ask. '
          'Growth and Premium let you move it yourself at any time and use '
          'one of your photos as the pin, so it stands out on the map.',
          style: AppText.bodyLarge.copyWith(color: palette.muted),
        ),
        const SizedBox(height: Insets.xl),
        if (AppConfig.teamWhatsApp.isNotEmpty)
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(
                'https://wa.me/${AppConfig.teamWhatsApp}?text='
                '${Uri.encodeComponent('Hi Dadliplug team, please move the map pin for ${b.name}. It should be: ')}',
              ),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Ask the team to move it'),
          )
        else
          Text(
            'Message the Dadliplug team to have it moved.',
            style: AppText.bodyMedium.copyWith(color: palette.ink),
          ),
      ],
    ),
  );

  Widget _editor(Business b, AppPalette palette) {
    final photos = [
      for (final p in b.photos)
        if (p.url case final url? when url.startsWith('https://')) url,
    ];
    final selectedPhoto = _photoTouched ? _photo : b.pinImageUrl;
    final start =
        _at ??
        (b.hasLocation
            ? (latitude: b.latitude!, longitude: b.longitude!)
            : (
                latitude: MapConfig.antiguaLatitude,
                longitude: MapConfig.antiguaLongitude,
              ));

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (AppConfig.hasGoogleMapsKey)
                PinPickerMap(
                  initial: start,
                  onMoved: (at) => setState(() => _at = at),
                )
              else
                const Center(child: Text('NO MAPS KEY in this build')),
              Positioned(
                left: Insets.lg,
                right: Insets.lg,
                top: Insets.lg,
                child: Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(Corners.md),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.md),
                    child: Text(
                      b.hasLocation
                          ? 'Drag the pin, or tap where your door is.'
                          : 'Tap where your door is to place your pin.',
                      style: AppText.bodyMedium.copyWith(color: palette.ink),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pin photo',
                  style: AppText.titleSmall.copyWith(color: palette.ink),
                ),
                const SizedBox(height: Insets.sm),
                SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _PhotoChoice(
                        selected: selectedPhoto == null,
                        onTap: () => setState(() {
                          _photoTouched = true;
                          _photo = null;
                        }),
                        child: Icon(b.category.icon, color: palette.onRed),
                      ),
                      for (final url in photos)
                        _PhotoChoice(
                          selected: selectedPhoto == url,
                          onTap: () => setState(() {
                            _photoTouched = true;
                            _photo = url;
                          }),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                          ),
                        ),
                    ],
                  ),
                ),
                if (photos.isEmpty)
                  Text(
                    'Add photos to your listing to use one as your pin.',
                    style: AppText.caption.copyWith(color: palette.muted),
                  ),
                const SizedBox(height: Insets.md),
                FilledButton(
                  onPressed: _busy || (_at == null && !_photoTouched)
                      ? null
                      : () => _save(b),
                  child: Text(_busy ? 'Saving…' : 'Save pin'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoChoice extends StatelessWidget {
  const _PhotoChoice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: Insets.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? palette.red : palette.line,
              width: selected ? 3 : 1,
            ),
          ),
          child: ClipOval(
            child: ColoredBox(
              color: palette.red,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
