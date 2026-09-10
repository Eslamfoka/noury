import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/profile/profile_photo.dart';

/// الصورة الشخصية, on disk.
///
/// The store lives in the application-support directory, which also holds the
/// database and the snooze store — so most of what is worth asserting here is
/// about what it must *not* touch.
void main() {
  late Directory dir;
  late ProfilePhotoStore store;

  /// A file standing in for whatever the picker hands back.
  File source(String name, [String bytes = 'not really a jpeg']) {
    final f = File('${dir.path}/incoming/$name');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(bytes);
    return f;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nouri-photo-');
    store = ProfilePhotoStore(dir);
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
  });

  List<String> storedNames() => dir
      .listSync()
      .whereType<File>()
      .map((f) => f.path.split(RegExp(r'[/\\]')).last)
      .toList()
    ..sort();

  test('copies the picked file in and reports where it went', () async {
    final path = await store.save(source('pic.jpg').path);

    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(File(path).readAsStringSync(), 'not really a jpeg');
    expect(path.startsWith(dir.path), isTrue,
        reason: 'the photo belongs beside the database, not where the OS '
            'happened to cache it — the picker hands back a path into a cache '
            'that can be cleared at any moment');
  });

  test('a second photo replaces the first rather than joining it', () async {
    await store.save(source('one.jpg', 'first').path);
    final second = await store.save(source('two.png', 'second').path);

    expect(storedNames(), hasLength(1),
        reason: 'a picker used twenty times must not leave twenty images on '
            "the user's phone");
    expect(File(second!).readAsStringSync(), 'second');
  });

  test('the stored name changes between saves', () async {
    // Not for uniqueness — there is only ever one file. Flutter caches a
    // decoded image against its path, so writing a new photo under the old
    // name would leave the screen showing the previous one until the app
    // restarted, which reads as "the picker did not work".
    final first = await store.save(source('a.jpg').path);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await store.save(source('b.jpg').path);

    expect(second, isNot(first));
  });

  test('it never deletes a file it did not write', () async {
    // The real directory holds nouri.db and snoozes.json. A cleanup pattern
    // that reached either of those would be a data-loss bug wearing an
    // innocent name.
    final database = File('${dir.path}/nouri.db')..writeAsStringSync('sqlite');
    final snoozes = File('${dir.path}/snoozes.json')..writeAsStringSync('{}');

    await store.save(source('pic.jpg').path);
    await store.remove();

    expect(database.existsSync(), isTrue);
    expect(snoozes.existsSync(), isTrue);
  });

  test('remove leaves nothing of its own behind', () async {
    await store.save(source('pic.jpg').path);
    await store.remove();

    expect(storedNames().where((n) => n.startsWith('profile-')), isEmpty);
  });

  test('a source that is gone returns null instead of throwing', () async {
    // The picker returns a path into a cache the OS may clear underneath it.
    // A photo that could not be copied is worth a shrug, not a crash on a
    // screen the user opened to fill in his name.
    expect(await store.save('${dir.path}/nothing-here.jpg'), isNull);
  });

  test('removing when there was never a photo is quiet', () async {
    await store.remove();
    expect(storedNames(), isEmpty);
  });

  test('an odd extension is stored as a jpeg rather than trusted', () async {
    final path = await store.save(source('pic.this-is-not-an-extension').path);
    expect(path!.endsWith('.jpg'), isTrue);
  });

  test('a known extension is kept, lower-cased', () async {
    final path = await store.save(source('PIC.PNG').path);
    expect(path!.endsWith('.png'), isTrue);
  });
}
