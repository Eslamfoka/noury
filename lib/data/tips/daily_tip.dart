import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// The three pillars a tip can come from, in rotation order.
enum TipPillar { deen, body, wealth }

extension TipPillarAsset on TipPillar {
  String get asset => 'assets/tips/$name.json';

  /// Shown as a small label beside the line, so the user can see which part of
  /// their life Nouri is nudging.
  String get arabicLabel => switch (this) {
        TipPillar.deen => 'الديني',
        TipPillar.body => 'البدني',
        TipPillar.wealth => 'المالي',
      };
}

class Tip {
  const Tip({required this.id, required this.text, required this.pillar});

  final String id;
  final String text;
  final TipPillar pillar;

  factory Tip.fromJson(Map<String, dynamic> j, TipPillar pillar) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final text = (j['text'] as String?)?.trim() ?? '';

    if (id.isEmpty) throw const FormatException('tip has no id');
    if (text.isEmpty) throw FormatException('tip $id has no text');

    return Tip(id: id, text: text, pillar: pillar);
  }
}

class TipSet {
  const TipSet({required this.pillar, required this.items, this.note});

  final TipPillar pillar;
  final List<Tip> items;

  /// The medical / financial framing the brief requires, carried with the
  /// content rather than hardcoded in the UI.
  final String? note;

  factory TipSet.fromJson(Map<String, dynamic> j) {
    final pillar = TipPillar.values.firstWhere(
      (p) => p.name == j['pillar'],
      orElse: () => throw FormatException('unknown pillar ${j['pillar']}'),
    );

    final items = (j['items'] as List)
        .map((e) => Tip.fromJson(e as Map<String, dynamic>, pillar))
        .toList();

    if (items.map((t) => t.id).toSet().length != items.length) {
      throw FormatException('duplicate tip ids in ${pillar.name}');
    }

    return TipSet(
      pillar: pillar,
      items: items,
      note: (j['note'] as String?)?.trim(),
    );
  }
}

/// The epoch the rotation counts from. Fixed so the sequence is reproducible.
final _rotationEpoch = DateTime.utc(2026, 1, 1);

int _dayIndex(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).difference(_rotationEpoch).inDays;

/// Which pillar today's tip comes from.
///
/// Cycles deen → body → wealth by day, so all three pillars surface every
/// three days rather than one dominating by chance.
TipPillar pillarForDay(DateTime date) =>
    TipPillar.values[_dayIndex(date) % TipPillar.values.length];

/// Today's tip, chosen deterministically from [sets].
///
/// Deterministic rather than random on purpose: the line stays the same all
/// day (it does not flicker on rebuild or tab switch), it is reproducible in
/// tests, and it needs no stored state. Walking the list by a stride derived
/// from the day means the whole set is seen before anything repeats.
Tip? tipForDay(DateTime date, Map<TipPillar, TipSet> sets) {
  final pillar = pillarForDay(date);
  final items = sets[pillar]?.items;
  if (items == null || items.isEmpty) return null;

  // Each pillar advances once every three days, so divide before indexing —
  // otherwise two thirds of each list would never be shown.
  final cycle = _dayIndex(date) ~/ TipPillar.values.length;
  return items[cycle % items.length];
}

class TipRepository {
  TipRepository({Future<String> Function(String)? loadAsset})
      : _loadAsset = loadAsset ?? rootBundle.loadString;

  final Future<String> Function(String) _loadAsset;
  Map<TipPillar, TipSet>? _cache;

  Future<Map<TipPillar, TipSet>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final sets = <TipPillar, TipSet>{};
    for (final pillar in TipPillar.values) {
      final raw = await _loadAsset(pillar.asset);
      sets[pillar] =
          TipSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }

    _cache = sets;
    return sets;
  }
}
