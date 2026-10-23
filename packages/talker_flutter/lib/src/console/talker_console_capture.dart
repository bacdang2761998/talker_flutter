import 'dart:async';

import 'package:talker_flutter/talker_flutter.dart';

/// One console line (`print` / `debugPrint`) captured into [Talker]
class TalkerConsoleLog extends TalkerLog {
  TalkerConsoleLog(String line, {String key = defaultKey})
      : super(line, key: key, title: key);

  static const defaultKey = 'console';

  @override
  String generateTextMessage({
    TimeFormat timeFormat = TimeFormat.timeAndSeconds,
  }) =>
      '[$title] ${message ?? ''}';
}

/// Copies the app's console lines into [talker] through a [Zone].
///
/// Flutter's `debugPrint` ends in `print`, so a zone `print` handler sees
/// both, from the app and from packages (Dart side). `dart:developer` `log`
/// does not go through the zone. The console still prints every line.
///
/// Lines are captured only while `talker.settings.useConsoleLogs` is on, i.e.
/// Talker is enabled and the "Use console logs" switch of the settings sheet
/// is on. Pair it with a no-op `TalkerLogger` output, otherwise every captured
/// line is printed a second time by Talker.
///
/// ```dart
/// runZonedGuarded(
///   () => runApp(...),
///   onError,
///   zoneSpecification: TalkerConsoleCapture(talker: talker).zoneSpecification,
/// );
/// ```
class TalkerConsoleCapture {
  TalkerConsoleCapture({
    required this.talker,
    this.key = TalkerConsoleLog.defaultKey,
    this.mask = TalkerConsoleMask.mask,
    this.ignorePrefixes = const [],
    this.maxLineChars = 2000,
  });

  final Talker talker;

  /// Log key (and filter chip) of captured lines
  final String key;

  /// Applied to every line before it is stored: the log never holds the raw
  /// line, so search, copy and share only see the masked text
  final String Function(String line) mask;

  /// Lines starting with one of these are not captured
  final List<String> ignorePrefixes;

  /// Longer lines are cut, with the number of dropped chars appended
  final int maxLineChars;

  var _capturing = false;

  ZoneSpecification get zoneSpecification => ZoneSpecification(
        print: (self, parent, zone, line) {
          parent.print(zone, line);
          capture(line);
        },
      );

  /// Logging is best effort: a failure never breaks `print`
  void capture(String line) {
    if (_capturing || !talker.settings.useConsoleLogs) return;
    for (final prefix in ignorePrefixes) {
      if (line.startsWith(prefix)) return;
    }
    _capturing = true;
    try {
      talker.logCustom(TalkerConsoleLog(mask(_clip(line)), key: key));
    } on Object {
      // Drop this line.
    } finally {
      _capturing = false;
    }
  }

  String _clip(String line) => line.length <= maxLineChars
      ? line
      : '${line.substring(0, maxLineChars)}'
          '… (+${line.length - maxLineChars} chars)';
}

/// Masks secrets in one line of free text, by pattern only: `Bearer …`, and
/// the value of keys whose name contains token, password, secret, api key,
/// authorization or cookie (`k=v`, `k: v`, `"k":"v"`; a quoted value is
/// masked up to its closing quote). Coordinates, phone numbers and the like
/// inside the text are NOT masked.
abstract final class TalkerConsoleMask {
  static const redacted = '<redacted>';

  static final _bearer = RegExp(
    r'\bBearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final _keyValue = RegExp(
    r'''(["']?)([\w.-]*(?:token|password|passwd|secret|api[_-]?key|authorization|cookie)[\w.-]*)\1(\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^"'\s,&;}\]]+)''',
    caseSensitive: false,
  );

  /// `Bearer` first: the key rule alone would take only the word `Bearer` as
  /// the value of `Authorization:` and leave the token behind it
  static String mask(String line) => line
          .replaceAll(_bearer, 'Bearer $redacted')
          .replaceAllMapped(_keyValue, (m) {
        final value = m[0]!.substring(m[0]!.indexOf(m[3]!) + m[3]!.length);
        final quote =
            value.startsWith('"') || value.startsWith("'") ? value[0] : '';
        return '${m[1]}${m[2]}${m[1]}${m[3]}$quote$redacted$quote';
      });
}
