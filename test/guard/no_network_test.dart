import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Slice 1 was entirely offline, and this file was the enforcement of that:
/// no network package, no `HttpClient(`, no host literal, and `INTERNET`
/// removed from the manifest so the OS itself made a connection impossible.
///
/// On 10 September 2026 the user said yes to the one call the brief always
/// planned — «ابني خطتي» — and on 13 September asked for the CONNECT part,
/// to any AI service he holds a key for. So the guard **narrows rather than
/// disappears**, exactly as the 9 September spec §3 said it would:
///
/// - **exactly one file** may open a socket — `lib/features/ai/ai_http_client.dart`;
/// - the only hosts that may be named anywhere under `lib/` are the three
///   AI services in `ai_provider.dart`, and no other file may name a URL;
/// - no direct dependency may reach the network on its own — the socket is
///   `dart:io`, which the one file uses in the open;
/// - `INTERNET` is in the manifest, once, granted, because the OS has to
///   allow the one call.
///
/// That is a stronger statement than the old one for everything except the
/// call the user asked for, and it is still checkable. Widening any of it
/// should fail here first.
void main() {
  /// The one file allowed to open a connection.
  const socketFile = 'lib/features/ai/ai_http_client.dart';

  /// The one file allowed to say where connections go.
  const hostsFile = 'lib/features/ai/ai_provider.dart';

  /// The only hosts Nouri may ever name.
  const allowedHosts = {
    'https://api.anthropic.com',
    'https://api.openai.com/v1',
    'https://generativelanguage.googleapis.com',
  };

  /// Direct dependencies that would give the app network reach of their own.
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

  Iterable<File> dartFilesUnderLib() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  String normalised(String path) => path.replaceAll('\\', '/');

  test('no direct dependency can reach the network on its own', () {
    final offenders = directDependencyNames().intersection(bannedPackages);
    expect(offenders, isEmpty,
        reason: 'the socket is dart:io in one file, not a package: $offenders');
  });

  test('the dependency parser actually sees the real dependencies', () {
    // Guards the test above: a parser that silently matched nothing would make
    // the offline check vacuously pass forever.
    final names = directDependencyNames();
    expect(names, contains('drift'));
    expect(names, contains('flutter_test'));
    expect(names.length, greaterThan(5));
  });

  test('exactly one file opens a connection', () {
    final offenders = <String>[];
    var found = false;
    for (final f in dartFilesUnderLib()) {
      final src = f.readAsStringSync();
      final opens = src.contains('HttpClient(') ||
          src.contains('package:http/') ||
          src.contains('Socket.connect') ||
          src.contains('WebSocket.connect');
      if (!opens) continue;
      if (normalised(f.path) == socketFile) {
        found = true;
      } else {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'only $socketFile may open a connection; found: $offenders');
    expect(found, isTrue,
        reason: '$socketFile should be the file that opens one — if it '
            'moved, move this guard with it');
  });

  test('the only hosts named anywhere are the three AI services', () {
    final url = RegExp(r'''https?://[^\s'"]+''');
    final offenders = <String>[];

    for (final f in dartFilesUnderLib()) {
      // Generated code carries no URLs of its own, but it is large and
      // scanning it costs nothing, so it is not exempted.
      final src = f.readAsStringSync();
      for (final m in url.allMatches(src)) {
        final literal = m.group(0)!;
        // Doc comments name consoles for the user's benefit; only string
        // literals reach the wire. A URL inside a comment line is skipped.
        final lineStart = src.lastIndexOf('\n', m.start) + 1;
        final line = src.substring(lineStart, m.start);
        if (line.trimLeft().startsWith('//')) continue;

        final ok = normalised(f.path) == hostsFile &&
            allowedHosts.any((h) => literal == h);
        if (!ok) offenders.add('${f.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: 'a URL outside $hostsFile, or a host that is not one of the '
            'three: $offenders');
  });

  test('every allowed host is actually the one the provider uses', () {
    // Keeps the set above honest: if a provider's URL changes, this list
    // has to be changed on purpose, in the same commit.
    final src = File(hostsFile).readAsStringSync();
    for (final host in allowedHosts) {
      expect(src, contains("'$host'"), reason: host);
    }
  });

  test('the android manifest grants INTERNET, once, for the one call', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    final mentions = RegExp(r'<uses-permission[^>]*android\.permission\.INTERNET[^>]*>')
        .allMatches(manifest)
        .map((m) => m.group(0)!)
        .toList();

    expect(mentions, hasLength(1),
        reason: 'INTERNET should be declared exactly once');
    expect(mentions.single.contains('tools:node="remove"'), isFalse,
        reason: 'it used to be removed; since 13 September 2026 the one '
            'call needs it: ${mentions.single}');
  });

  test('no other source set adds anything to the network story', () {
    // debug and profile declare INTERNET for hot reload and the VM service,
    // which is Flutter's own and must not be "fixed". Nothing else should.
    final offenders = <String>[];
    for (final entry
        in Directory('android/app/src').listSync().whereType<Directory>()) {
      final sourceSet = entry.path.split(RegExp(r'[/\\]')).last;
      if (sourceSet == 'main' || sourceSet == 'debug' || sourceSet == 'profile') {
        continue;
      }
      final manifest = File('${entry.path}/AndroidManifest.xml');
      if (!manifest.existsSync()) continue;
      if (manifest.readAsStringSync().contains('INTERNET')) {
        offenders.add(sourceSet);
      }
    }
    expect(offenders, isEmpty, reason: offenders.toString());
  });
}
