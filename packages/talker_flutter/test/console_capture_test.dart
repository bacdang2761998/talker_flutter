// The tests call `print` on purpose: it is the way into the zone under test.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

Talker _talker({bool useConsoleLogs = true}) => Talker(
      logger: TalkerLogger(output: (_) {}),
      settings: TalkerSettings(useConsoleLogs: useConsoleLogs),
    );

/// Runs [body] in the capture zone; [printed] gets what the console received
Future<void> _run(
  TalkerConsoleCapture capture,
  List<String> printed,
  FutureOr<void> Function() body,
) async {
  await runZoned(
    () => runZoned(
      () async => body(),
      zoneSpecification: capture.zoneSpecification,
    ),
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => printed.add(line),
    ),
  );
}

List<String> _messages(Talker talker) => [
      for (final log in talker.history)
        if (log is TalkerConsoleLog) log.message ?? '',
    ];

void main() {
  test('print and debugPrint are captured, console still prints', () async {
    final talker = _talker();
    final printed = <String>[];
    await _run(TalkerConsoleCapture(talker: talker, key: 'app-log'), printed,
        () {
      print('hello');
      debugPrintSynchronously('from debugPrint');
    });
    expect(_messages(talker), ['hello', 'from debugPrint']);
    expect(printed, ['hello', 'from debugPrint']);
    expect(talker.history.map((e) => e.key).toSet(), {'app-log'});
  });

  test('"Use console logs" off or Talker disabled: nothing captured', () async {
    final off = _talker(useConsoleLogs: false);
    await _run(TalkerConsoleCapture(talker: off), [], () => print('a'));
    final disabled = _talker()..disable();
    await _run(TalkerConsoleCapture(talker: disabled), [], () => print('b'));
    expect(off.history, isEmpty);
    expect(disabled.history, isEmpty);
  });

  test('ignorePrefixes skips lines', () async {
    final talker = _talker();
    await _run(
      TalkerConsoleCapture(talker: talker, ignorePrefixes: ['[API] ']),
      [],
      () {
        print('[API] seq=1 auth 1/2 eyJ');
        print('app line');
      },
    );
    expect(_messages(talker), ['app line']);
  });

  test('stored text is masked; a custom mask replaces the default', () async {
    final talker = _talker();
    await _run(TalkerConsoleCapture(talker: talker), [], () {
      print('Authorization: Bearer eyJ.abc.def');
      print('refresh accessToken=abc123&lang=vi');
    });
    final text = _messages(talker).join('\n');
    expect(text, isNot(contains('eyJ.abc.def')));
    expect(text, isNot(contains('abc123')));
    expect(text, contains('lang=vi'));

    final custom = _talker();
    await _run(
      TalkerConsoleCapture(talker: custom, mask: (l) => l.toUpperCase()),
      [],
      () => print('abc'),
    );
    expect(_messages(custom), ['ABC']);
  });

  test('long lines are cut', () async {
    final talker = _talker();
    await _run(TalkerConsoleCapture(talker: talker, maxLineChars: 10), [],
        () => print('x' * 25));
    expect(_messages(talker).single, '${'x' * 10}… (+15 chars)');
  });

  test('text for search/copy is the masked line with its key', () {
    final log = TalkerConsoleLog('a', key: 'app-log');
    expect(log.generateTextMessage(), '[app-log] a');
  });

  group('TalkerConsoleMask', () {
    test('quoted value masked up to the closing quote, quote kept', () {
      expect(
        TalkerConsoleMask.mask('{"password":"my secret pass","name":"An"}'),
        '{"password":"<redacted>","name":"An"}',
      );
      expect(TalkerConsoleMask.mask("password='a b c' x=1"),
          "password='<redacted>' x=1");
    });

    test('key match is by name part, other keys untouched', () {
      expect(TalkerConsoleMask.mask('api_key: k1 shipping=x'),
          'api_key: <redacted> shipping=x');
    });
  });
}
