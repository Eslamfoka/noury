import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'athkar_item.dart';

/// Loads athkar from the bundled JSON assets.
///
/// The content is a versioned asset rather than database rows: it is static,
/// diffable in git, and reviewable as a file — which matters for religious
/// text. See `docs/athkar-verification.md`.
class AthkarRepository {
  AthkarRepository({Future<String> Function(String)? loadAsset})
      : _loadAsset = loadAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _loadAsset;
  final Map<String, AthkarSet> _cache = {};

  static const categories = <String>['morning', 'evening', 'sleep', 'tasbeeh'];

  /// Throws [FormatException] on malformed content — loudly, never silently,
  /// because a dhikr missing its source is a defect that must not ship.
  Future<AthkarSet> load(String category) async {
    final cached = _cache[category];
    if (cached != null) return cached;

    final raw = await _loadAsset('assets/athkar/$category.json');
    final set = AthkarSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    if (set.category != category) {
      throw FormatException(
        'athkar asset $category.json declares category "${set.category}"',
      );
    }

    _cache[category] = set;
    return set;
  }
}
