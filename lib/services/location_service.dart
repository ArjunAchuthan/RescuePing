import 'package:geolocator/geolocator.dart';

/// Battery-efficient GPS helper.
///
/// Grabs location **only once** when called — no continuous tracking.
/// Falls back to last-known position if a fresh fix times out.
class LocationService {
  LocationService();

  /// Get the device's current location (one-shot).
  ///
  /// Returns `null` if location services are off or permission denied.
  /// Timeout: [timeout] (default 10 s).
  Future<Position?> getLocationOnce({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Check if location services are enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _lastKnown();

    // Check permission.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _lastKnown();
      }
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Good enough, less battery
        ),
      ).timeout(timeout);
    } catch (_) {
      return _lastKnown();
    }
  }

  Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
