import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// الصورة الشخصية — the one thing on الملف الشخصي that was still a promise.
///
/// **A file beside the database, never a column.** A few hundred KB of JPEG in
/// a row that every settings read touches would slow every one of those reads
/// for something drawn on one screen. The database keeps only the path.
///
/// **It feeds nothing.** The photo is not in [PlanRequest] and never will be —
/// a test asserts that directly. Nouri is being asked to place time, and a
/// face is not time. Every other field on that screen states what it changes;
/// this one's honest answer is *nothing*, and the screen says so rather than
/// implying the picture buys a better plan.
class ProfilePhotoStore {
  ProfilePhotoStore(this.directory);

  final Directory directory;

  /// Filenames carry a timestamp rather than being fixed.
  ///
  /// Not for uniqueness — there is only ever one — but because Flutter caches
  /// a decoded image against its path. Writing a new photo to `profile.jpg`
  /// would leave the screen showing the previous one until the app restarted,
  /// which reads as "the picker did not work".
  static final _mine = RegExp(r'^profile-\d+\.[A-Za-z0-9]+$');

  /// Copies [sourcePath] in and returns where it now lives.
  ///
  /// The previous photo is removed in the same pass, so this directory holds
  /// one file or none — a picker used twenty times must not leave twenty
  /// images behind on a phone.
  ///
  /// Returns null when the source cannot be read. That is not a crash: the
  /// picker hands back a path into a cache the OS may clear at any moment, and
  /// a photo that could not be copied is worth exactly a shrug.
  Future<String?> save(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!source.existsSync()) return null;

      await directory.create(recursive: true);
      await _removeMine();

      final extension = _extensionOf(sourcePath);
      final target = File(
        '${directory.path}/profile-'
        '${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      await source.copy(target.path);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  /// Forgets the photo — a value the user can set is a value they can unset,
  /// which is the rule a birth date had to learn the hard way.
  Future<void> remove() async {
    try {
      await _removeMine();
    } catch (_) {
      // A file that will not delete costs disk space, never correctness.
    }
  }

  Future<void> _removeMine() async {
    if (!directory.existsSync()) return;
    for (final entity in directory.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      // Only files this class wrote. The application-support directory also
      // holds the database and the snooze store, and a pattern that reached
      // either of those would be a data-loss bug wearing a cleanup.
      if (_mine.hasMatch(name)) entity.deleteSync();
    }
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '.jpg';
    final extension = name.substring(dot);
    // Android resource-style caution: anything unexpected becomes .jpg rather
    // than being trusted into a filename.
    return RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(extension)
        ? extension.toLowerCase()
        : '.jpg';
  }
}

/// Choosing a photo and storing it, as one seam.
///
/// Returns where the photo now lives, or null when the user backed out or the
/// copy failed. A single function rather than a picker and a store separately,
/// because the widget has no business knowing there are two steps — and
/// because one override is all a test needs.
typedef PhotoChooser = Future<String?> Function();

final photoChooserProvider = Provider<PhotoChooser>((ref) => choosePhoto);

/// The real one.
///
/// **No permission is requested and none is declared.** On Android 13+ this
/// opens the system photo picker, which hands back exactly the one image the
/// user chose and gives Nouri no access to anything else. Asking for
/// `READ_MEDIA_IMAGES` would buy nothing and would be a worse trade: this app
/// tells the user what each answer costs, and "let me read all your photos"
/// for a thumbnail is not a trade worth offering.
///
/// Resized on the way in. A modern phone camera produces several MB; the
/// picture is drawn at 64 logical pixels.
Future<String?> choosePhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (picked == null) return null;

  final store = ProfilePhotoStore(await getApplicationSupportDirectory());
  return store.save(picked.path);
}

/// Removing it, as its own seam for the same reason.
typedef PhotoRemover = Future<void> Function();

final photoRemoverProvider = Provider<PhotoRemover>((ref) => removePhoto);

Future<void> removePhoto() async {
  final store = ProfilePhotoStore(await getApplicationSupportDirectory());
  await store.remove();
}
