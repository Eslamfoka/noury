import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Slice 1 is entirely offline: prayer times are computed on-device, athkar are
/// a bundled asset, and nothing is ever sent anywhere. This test is the
/// enforcement of that, not a comment about it.
///
/// The AI layer arrives in Slice 5. When it does, this test is the thing that
/// must be deliberately changed — which is the point: adding a network call
/// should be a decision, never an accident.
void main() {
  /// Direct dependencies that would give the app network reach.
  /// Transitive dev-tool dependencies (build_runner pulls web_socket_channel)
  /// are irrelevant — they never ship in the APK.
  const bannedPackages = {
    'http',
    'dio',
    'anthropic',
    'anthropic_sdk_dart',
    'web_socket_channel',
    'grpc',
    'socket_io_client',
    'graphql',
  };

  Set<String> directDependencyNames() {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final names = <String>{};
    var inDeps = false;

    for (final line in lines) {
      if (line.startsWith('dependencies:') ||
          line.startsWith('dev_dependencies:')) {
        inDeps = true;
        continue;
      }
      // A new top-level key ends the dependency block.
      if (inDeps && line.isNotEmpty && !line.startsWith(' ')) {
        inDeps = false;
        continue;
      }
      if (!inDeps) continue;

      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
      if (m != null) names.add(m.group(1)!);
    }
    return names;
  }

  test('no direct dependency can reach the network', () {
    final offenders = directDependencyNames().intersection(bannedPackages);
    expect(offenders, isEmpty,
        reason: 'Slice 1 must stay offline, found: $offenders');
  });

  test('the dependency parser actually sees the real dependencies', () {
    // Guards the test above: a parser that silently matched nothing would make
    // the offline check vacuously pass forever.
    final names = directDependencyNames();
    expect(names, contains('drift'));
    expect(names, contains('flutter_test'));
    expect(names.length, greaterThan(5));
  });

  test('no source file reaches the network', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('package:http/') ||
          src.contains('HttpClient(') ||
          src.contains('api.anthropic.com')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'network access found in: $offenders');
  });

  test('the android manifest grants no INTERNET permission', () {
    // A transitive dependency (package:http, pulled in by the notification
    // plugins) would otherwise merge INTERNET into the final manifest. The
    // manifest therefore names it explicitly with tools:node="remove", which
    // is a stronger guarantee than mere absence: the OS itself then makes
    // network access impossible, whatever any dependency tries to do.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    final mentions = RegExp(r'<uses-permission[^>]*android\.permission\.INTERNET[^>]*>')
        .allMatches(manifest)
        .map((m) => m.group(0)!)
        .toList();

    expect(mentions, hasLength(1),
        reason: 'INTERNET should be named exactly once, to remove it');
    expect(mentions.single.contains('tools:node="remove"'), isTrue,
        reason: 'INTERNET must be removed, never granted: ${mentions.single}');
  });

  test('the manifest declares the tools namespace the removal needs', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest.contains('xmlns:tools='), isTrue,
        reason: 'without the tools namespace, node="remove" is inert');
  });

  test('only the debug and profile manifests may add INTERNET', () {
    // Checking the main manifest alone gave false confidence: a debug APK
    // really does ship INTERNET, because Flutter's own debug source set
    // declares it for hot reload and the VM service, and debug/profile
    // outrank main in manifest merging.
    //
    // That is correct and must not be "fixed" -- removing it breaks
    // `flutter run`. What matters is that no OTHER source set adds it, so the
    // release APK goes out without it.
    final offenders = <String>[];
    for (final entry
        in Directory('android/app/src').listSync().whereType<Directory>()) {
      final sourceSet = entry.path.split(RegExp(r'[/\\]')).last;
      final manifest = File('${entry.path}/AndroidManifest.xml');
      if (!manifest.existsSync()) continue;

      final declaresInternet = manifest
          .readAsStringSync()
          .contains(RegExp(r'<uses-permission[^>]*INTERNET(?![^>]*node="remove")'));

      if (declaresInternet && sourceSet != 'debug' && sourceSet != 'profile') {
        offenders.add(sourceSet);
      }
    }

    expect(offenders, isEmpty,
        reason: 'these source sets would put INTERNET in a release APK: '
            '$offenders');
  });
}
