import 'package:antigua_business_map/services/listing_filter_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Why "near me" could not get a position. Each reads differently to the
/// viewer: a switched-off location service is fixed in settings, a refusal is
/// their choice and must not be nagged about.
enum LocationProblem { serviceOff, denied, deniedForever, failed }

/// Outcome of asking for the viewer's position.
sealed class LocationResult {
  const LocationResult();
}

class LocationFound extends LocationResult {
  const LocationFound(this.point);
  final GeoPoint point;
}

class LocationUnavailable extends LocationResult {
  const LocationUnavailable(this.problem);
  final LocationProblem problem;
}

/// The viewer's position for "near me", and nothing else.
///
/// Asked for only when the viewer picks a nearest-first sort, never at
/// startup. Coarse accuracy, because ranking a list needs a neighbourhood,
/// not a doorstep. The result is returned to the caller and never stored or
/// sent anywhere (plan.md section 12).
class ViewerLocation {
  const ViewerLocation();

  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(LocationProblem.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationUnavailable(LocationProblem.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationUnavailable(LocationProblem.denied);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationFound(GeoPoint(position.latitude, position.longitude));
    } catch (e) {
      debugPrint('Near me: could not get a position: $e');
      return const LocationUnavailable(LocationProblem.failed);
    }
  }
}

/// What to tell the viewer when "near me" has no position.
String describeLocationProblem(LocationProblem problem) => switch (problem) {
  LocationProblem.serviceOff =>
    'Location is switched off on this phone. Turn it on to sort by distance.',
  LocationProblem.denied =>
    'Showing the usual order. Allow location to sort by distance.',
  LocationProblem.deniedForever =>
    'Location is blocked for Dadliplug. You can allow it in Settings.',
  LocationProblem.failed =>
    'Could not find your location. Showing the usual order.',
};
