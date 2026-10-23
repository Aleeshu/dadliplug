import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:antigua_business_map/core/config/map_defaults.dart';
import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/features/business_admin/pin_editor_screen.dart'
    show isOnTheIslands;
import 'package:antigua_business_map/features/map/island_ads_map.dart';
import 'package:flutter/material.dart';

/// A point picked on the map.
typedef PickedLocation = ({double latitude, double longitude});

/// Pick where a business is by dropping its pin on a satellite map, instead
/// of typing coordinates. Returns the point, or null if cancelled.
///
/// Used by the listing editor (new listings, and the team editing any
/// listing). Owners moving their own pin use the pin screen, which also
/// applies the plan rules.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({this.initial, super.key});

  final PickedLocation? initial;

  static Future<PickedLocation?> pick(
    BuildContext context, {
    PickedLocation? initial,
  }) => Navigator.of(context).push<PickedLocation>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerScreen(initial: initial),
    ),
  );

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late PickedLocation? _at = widget.initial;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final at = _at;
    final start =
        at ??
        (
          latitude: MapConfig.antiguaLatitude,
          longitude: MapConfig.antiguaLongitude,
        );

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Where is the business?'),
        backgroundColor: palette.app,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (AppConfig.hasGoogleMapsKey)
                  PinPickerMap(
                    initial: start,
                    onMoved: (p) => setState(() => _at = p),
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
                        at == null
                            ? 'Zoom in and tap the front door to drop the pin.'
                            : 'Drag the pin to fine-tune, or tap somewhere else.',
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
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: at == null
                      ? null
                      : () {
                          if (!isOnTheIslands(at.latitude, at.longitude)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'That is off Antigua and Barbuda. Drop the '
                                  'pin again.',
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).pop(at);
                        },
                  child: const Text('Use this location'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
