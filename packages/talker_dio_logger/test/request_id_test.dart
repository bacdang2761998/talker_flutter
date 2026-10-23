import 'package:dio/dio.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/dio_logs.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:test/test.dart';

void main() {
  late Talker talker;

  setUp(() {
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
  });

  group('TalkerDioRequestId.generate', () {
    test('uses <microsecondsSinceEpoch>-<counter> format', () {
      expect(
        TalkerDioRequestId.generate(),
        matches(RegExp(r'^\d+-\d+$')),
      );
    });

    test('ids are unique across logger instances', () {
      final a = TalkerDioLogger(talker: talker);
      final b = TalkerDioLogger(talker: talker);
      final ids = <String>{};
      for (var i = 0; i < 500; i++) {
        final o1 = RequestOptions(path: '/a');
        final o2 = RequestOptions(path: '/b');
        a.onRequest(o1, RequestInterceptorHandler());
        b.onRequest(o2, RequestInterceptorHandler());
        ids.add(o1.extra['talker-request-id'] as String);
        ids.add(o2.extra['talker-request-id'] as String);
      }
      expect(ids, hasLength(1000));
    });
  });

  group('onRequest (D1)', () {
    test('stores id under default key and in request log', () {
      final logger = TalkerDioLogger(talker: talker);
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());

      final id = options.extra['talker-request-id'];
      expect(id, isA<String>());
      expect((talker.history.last as DioRequestLog).requestId, id);
    });

    test('uses configured requestIdKey', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(requestIdKey: 'rid'),
      );
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.extra['rid'], isA<String>());
      expect(options.extra.containsKey('talker-request-id'), isFalse);
    });

    test('assigns a new id on every send, even when options has one', () {
      final logger = TalkerDioLogger(talker: talker);
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      final first = options.extra['talker-request-id'];
      logger.onRequest(options, RequestInterceptorHandler());
      final second = options.extra['talker-request-id'];
      expect(second, isNot(first));
    });

    test('assigns id even when request is filtered out', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(requestFilter: (_) => false),
      );
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(talker.history, isEmpty);
      final id = options.extra['talker-request-id'];
      expect(id, isA<String>());

      logger.onResponse(
        Response(requestOptions: options, statusCode: 200),
        ResponseInterceptorHandler(),
      );
      expect((talker.history.last as DioResponseLog).requestId, id);
    });

    test('works with unmodifiable extra map', () {
      final logger = TalkerDioLogger(talker: talker);
      final options = RequestOptions(path: '/test', extra: const {'a': 1});
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.extra['a'], 1);
      expect(options.extra['talker-request-id'], isA<String>());
    });

    test('does nothing when logger is disabled', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(enabled: false),
      );
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.extra.containsKey('talker-request-id'), isFalse);
    });
  });

  group('requestIdBuilder (D3)', () {
    test('uses app-provided id', () {
      var n = 0;
      final logger = TalkerDioLogger(
        talker: talker,
        settings: TalkerDioLoggerSettings(
          requestIdBuilder: (o) => 'trace-${o.path}-${n++}',
        ),
      );
      final options = RequestOptions(path: '/x');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.extra['talker-request-id'], 'trace-/x-0');
      expect((talker.history.last as DioRequestLog).requestId, 'trace-/x-0');
    });
  });

  group('captured id (D4)', () {
    test('old logs keep their id after options is reused (retry)', () {
      final logger = TalkerDioLogger(talker: talker);
      final options = RequestOptions(path: '/test');

      logger.onRequest(options, RequestInterceptorHandler());
      logger.onError(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        ),
        _NoopErrorHandler(),
      );
      // retry: dio.fetch(err.requestOptions)
      logger.onRequest(options, RequestInterceptorHandler());
      logger.onResponse(
        Response(requestOptions: options, statusCode: 200),
        ResponseInterceptorHandler(),
      );

      final logs = talker.history;
      final firstId = (logs[0] as DioRequestLog).requestId;
      final secondId = (logs[2] as DioRequestLog).requestId;
      expect(firstId, isNot(secondId));
      expect((logs[1] as DioErrorLog).requestId, firstId);
      expect((logs[3] as DioResponseLog).requestId, secondId);
    });

    test('logs created directly read id from extra', () {
      const settings = TalkerDioLoggerSettings();
      final options = RequestOptions(
        path: '/test',
        extra: {'talker-request-id': 'abc'},
      );
      final log =
          DioRequestLog('m', requestOptions: options, settings: settings);
      expect(log.requestId, 'abc');
    });

    test('requestId is null without id in extra', () {
      final log = DioRequestLog(
        'm',
        requestOptions: RequestOptions(path: '/test'),
        settings: const TalkerDioLoggerSettings(),
      );
      expect(log.requestId, isNull);
    });
  });

  group('request id header (D5)', () {
    test('header is not sent by default', () {
      final logger = TalkerDioLogger(talker: talker);
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.headers.containsKey('X-Request-Id'), isFalse);
    });

    test('header is sent when enabled', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(
          sendRequestIdHeader: true,
          requestIdHeaderName: 'X-Trace',
        ),
      );
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      expect(options.headers['X-Trace'], options.extra['talker-request-id']);
    });
  });

  group('console output (D6)', () {
    test('id is not printed by default, nor shown in Extra', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(printRequestExtra: true),
      );
      final options = RequestOptions(path: '/test', extra: {'k': 'v'});
      logger.onRequest(options, RequestInterceptorHandler());
      final id = options.extra['talker-request-id'] as String;
      final text = talker.history.last.generateTextMessage();
      expect(text, isNot(contains(id)));
      expect(text, contains('"k": "v"'));
    });

    test('printRequestId prints id in title line', () {
      final logger = TalkerDioLogger(
        talker: talker,
        settings: const TalkerDioLoggerSettings(printRequestId: true),
      );
      final options = RequestOptions(path: '/test');
      logger.onRequest(options, RequestInterceptorHandler());
      logger.onResponse(
        Response(requestOptions: options, statusCode: 200),
        ResponseInterceptorHandler(),
      );
      logger.onError(
        DioException(requestOptions: options),
        _NoopErrorHandler(),
      );
      final id = options.extra['talker-request-id'] as String;
      for (final log in talker.history) {
        expect(
          log.generateTextMessage().split('\n').first,
          contains('[#$id]'),
        );
      }
    });
  });

  test('copyWith keeps and overrides request id settings', () {
    const s = TalkerDioLoggerSettings(requestIdKey: 'a', printRequestId: true);
    final c = s.copyWith(sendRequestIdHeader: true);
    expect(c.requestIdKey, 'a');
    expect(c.printRequestId, isTrue);
    expect(c.sendRequestIdHeader, isTrue);
    expect(c.requestIdHeaderName, 'X-Request-Id');
  });
}

class _NoopErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException err) {}
}
