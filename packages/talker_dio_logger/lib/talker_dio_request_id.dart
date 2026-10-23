import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger_settings.dart';

/// Request id helpers used by [TalkerDioLogger] to link the request,
/// response and error logs of one HTTP call.
class TalkerDioRequestId {
  const TalkerDioRequestId._();

  /// Shared by every logger instance, so two [Dio] clients never produce
  /// the same id.
  static int _counter = 0;

  /// Default id format: `<microsecondsSinceEpoch>-<counter>`
  static String generate() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  /// Assigns a new id to [options] on every send, even when [options]
  /// already holds one from a previous attempt (retry reusing the same
  /// [RequestOptions]). Returns the assigned id.
  static String assign(
    RequestOptions options,
    TalkerDioLoggerSettings settings,
  ) {
    final id = settings.requestIdBuilder?.call(options) ?? generate();
    try {
      options.extra[settings.requestIdKey] = id;
    } on UnsupportedError {
      // extra was created from an unmodifiable (const) map
      options.extra = {...options.extra, settings.requestIdKey: id};
    }
    if (settings.sendRequestIdHeader) {
      options.headers[settings.requestIdHeaderName] = id;
    }
    return id;
  }

  /// Reads the id currently stored in [options]
  static String? read(
    RequestOptions options,
    TalkerDioLoggerSettings settings,
  ) {
    final id = options.extra[settings.requestIdKey];
    return id is String ? id : null;
  }
}
