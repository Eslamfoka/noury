import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';

/// الملف الشخصي, and the fields the user added himself.
///
/// **`FutureProvider` and an explicit invalidate, not a stream.** Every other
/// database read in this app is shaped this way, and following the convention
/// is not only tidiness: a drift stream left listening keeps a timer alive
/// past the end of a widget test, which fails the whole file on
/// `!timersPending` — and it fails it *after* the assertions have passed, so
/// the message points nowhere near the cause. Writes here are rare and always
/// come from this screen, so there is nothing a stream would catch that an
/// invalidate does not.
final profileDaoProvider = Provider<ProfileDao>(
  (ref) => ref.watch(databaseProvider).profileDao,
);

final profileProvider = FutureProvider<ProfileRow>(
  (ref) => ref.watch(profileDaoProvider).get(),
);

final profileCustomFieldsProvider =
    FutureProvider<List<ProfileFieldRow>>(
  (ref) => ref.watch(profileDaoProvider).customFields(),
);

/// How much of the profile Nouri has to work with, 0..1.
///
/// Shown as a plain sentence rather than a progress bar, and **never as a
/// score**. The distinction matters: a bar at 40% is a mark out of ten for how
/// well the user has filled in a form about himself, which is exactly the
/// self-blame §1.2 of the brief forbids. The sentence says what a fuller
/// profile would buy him, and stops there.
final profileCompletenessProvider = Provider<double>((ref) {
  final p = ref.watch(profileProvider).value;
  final custom = ref.watch(profileCustomFieldsProvider).value ?? const [];
  if (p == null) return 0;

  final answered = <bool>[
    p.name != null,
    p.gender != null,
    p.birthDate != null,
    p.occupation != null,
    p.eatingNotes != null,
    p.sleepNotes != null,
    p.interests != null,
    custom.isNotEmpty,
  ].where((x) => x).length;

  return answered / 8;
});
