/// Where and how prayer times are computed.
class GeoConfig {
  const GeoConfig({
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.madhab,
  });

  final double latitude;
  final double longitude;

  /// kuwait | ummAlQura | muslimWorldLeague | egyptian | qatar | dubai
  final String method;

  /// shafi | hanafi
  final String madhab;

  /// Used before any location permission is granted.
  ///
  /// Nouri is never blocked on a permission — location only improves accuracy,
  /// and the app is fully usable without it.
  static const kuwaitCity = GeoConfig(
    latitude: 29.3759,
    longitude: 47.9774,
    method: 'kuwait',
    madhab: 'shafi',
  );

  GeoConfig copyWith({
    double? latitude,
    double? longitude,
    String? method,
    String? madhab,
  }) =>
      GeoConfig(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
      );
}
