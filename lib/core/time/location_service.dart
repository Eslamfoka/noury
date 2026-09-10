import 'package:geolocator/geolocator.dart';

/// A pair of coordinates and where they came from.
class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;

  /// device | fallback
  final String source;

  bool get isFallback => source == 'fallback';
}

/// The seam that makes location testable without a platform channel.
abstract class LocationPort {
  /// Returns the device's coordinates, or null if unavailable for any reason
  /// — permission denied, services off, hardware failure, timeout.
  ///
  /// Never throws. Nouri must never be blocked by a location failure.
  Future<ResolvedLocation?> current();
}

class GeolocatorLocationPort implements LocationPort {
  const GeolocatorLocationPort();

  /// Location is a nicety, not a dependency: if it takes more than this,
  /// Nouri stops waiting and keeps the coordinates it already has.
  static const timeout = Duration(seconds: 12);

  @override
  Future<ResolvedLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeout,
        ),
      );

      return ResolvedLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        source: 'device',
      );
    } catch (_) {
      // Every failure mode is the same to us: keep what we have.
      return null;
    }
  }
}
