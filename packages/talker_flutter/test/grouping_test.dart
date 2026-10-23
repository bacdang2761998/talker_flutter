import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Groups logs whose message starts with `#<id> `
class _IdGrouper extends TalkerLogGrouper {
  const _IdGrouper();

  @override
  String? groupKeyOf(TalkerData data) {
    final msg = data.message ?? '';
    if (!msg.startsWith('#')) return null;
    return msg.substring(1, msg.indexOf(' '));
  }
}

class _ThrowingGrouper extends TalkerLogGrouper {
  const _ThrowingGrouper({this.throwOnKey = false});

  final bool throwOnKey;

  @override
  String? groupKeyOf(TalkerData data) {
    if (throwOnKey) throw StateError('key');
    return const _IdGrouper().groupKeyOf(data);
  }

  @override
  Widget? buildGroup(context, group, theme) => throw StateError('build');

  @override
  String groupText(TalkerLogGroup group) => throw StateError('text');
}

class _CustomGrouper extends _IdGrouper {
  const _CustomGrouper();

  @override
  Widget? buildGroup(context, group, theme) =>
      Text('custom ${group.key} ${group.logs.length}');

  @override
  String groupText(TalkerLogGroup group) => 'GROUP ${group.key}';
}

TalkerData _log(String message, {String key = 'info'}) =>
    TalkerLog(message, key: key, title: key);

void main() {
  group('groupTalkerLogs', () {
    test('groups by key at first log position, keeps single logs', () {
      final logs = [
        _log('#1 req', key: 'http-request'),
        _log('plain'),
        _log('#2 req', key: 'http-request'),
        _log('#1 res', key: 'http-response'),
      ];
      final items = groupTalkerLogs(logs, const _IdGrouper());
      expect(items, hasLength(3));
      expect(items[0].group!.key, '1');
      expect(items[0].group!.logs.map((e) => e.message), ['#1 req', '#1 res']);
      expect(items[0].group!.first.message, '#1 req');
      expect(items[0].group!.last.message, '#1 res');
      expect(items[1].isGroup, isFalse);
      expect(items[1].data!.message, 'plain');
      expect(items[2].group!.logs, hasLength(1));
    });

    test('groupKeyOf throwing keeps logs single', () {
      final logs = [_log('#1 a'), _log('#1 b')];
      final items =
          groupTalkerLogs(logs, const _ThrowingGrouper(throwOnKey: true));
      expect(items.where((e) => e.isGroup), isEmpty);
      expect(items, hasLength(2));
    });

    test('without grouper every log is single', () {
      final logs = [_log('#1 a'), _log('#1 b')];
      final items = talkerLogItems(logs, null);
      expect(items.map((e) => e.data), logs);
    });

    test('1000 logs are grouped in linear time', () {
      final logs = [
        for (var i = 0; i < 500; i++) ...[
          _log('#$i req', key: 'http-request'),
          _log('#$i res', key: 'http-response'),
        ],
      ];
      final sw = Stopwatch()..start();
      final items = groupTalkerLogs(logs, const _IdGrouper());
      sw.stop();
      expect(items, hasLength(500));
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('filterTalkerLogItems', () {
    final logs = [
      _log('#1 /users', key: 'http-request'),
      _log('#1 200', key: 'http-response'),
      _log('#2 /orders', key: 'http-request'),
      _log('#2 500', key: 'http-error'),
      _log('plain info'),
    ];
    final items = groupTalkerLogs(logs, const _IdGrouper());

    test('key filter keeps whole group when one log matches', () {
      final res = filterTalkerLogItems(
        items,
        TalkerFilter(enabledKeys: ['http-error']),
      );
      expect(res, hasLength(1));
      expect(res.single.group!.logs.map((e) => e.key),
          ['http-request', 'http-error']);
    });

    test('key filter checks the last log: request = pending only', () {
      final pending = groupTalkerLogs(
        [...logs, _log('#3 /slow', key: 'http-request')],
        const _IdGrouper(),
      );
      final res = filterTalkerLogItems(
        pending,
        TalkerFilter(enabledKeys: ['http-request']),
      );
      expect(res.map((e) => e.group!.key), ['3']);
    });

    test('key filter checks the last log: response = done calls', () {
      final res = filterTalkerLogItems(
        items,
        TalkerFilter(enabledKeys: ['http-response']),
      );
      expect(res.map((e) => e.group!.key), ['1']);
    });

    test('search + key: search any log, key on the last log', () {
      final res = filterTalkerLogItems(
        items,
        TalkerFilter(enabledKeys: ['http-error'], searchQuery: '/orders'),
      );
      expect(res.single.group!.key, '2');
      expect(
        filterTalkerLogItems(
          items,
          TalkerFilter(enabledKeys: ['http-error'], searchQuery: '/users'),
        ),
        isEmpty,
      );
    });

    test('single logs keep the plain filter', () {
      final res = filterTalkerLogItems(
        items,
        TalkerFilter(enabledKeys: ['info']),
      );
      expect(res.single.data!.message, 'plain info');
    });

    test('item keys count a group once, by its last log', () {
      expect(talkerLogItemKeys(items), ['http-response', 'http-error', 'info']);
    });

    test('search matches text of any group log', () {
      final res = filterTalkerLogItems(
        items,
        TalkerFilter(searchQuery: '/users'),
      );
      expect(res.single.group!.key, '1');
      expect(res.single.group!.logs, hasLength(2));
    });
  });

  group('text', () {
    final logs = [_log('#1 a'), _log('x'), _log('#1 b')];

    test('default groupText joins log texts', () {
      final group = groupTalkerLogs(logs, const _IdGrouper()).first.group!;
      final text = const _IdGrouper().groupText(group);
      expect(text, contains('#1 a'));
      expect(text, contains('#1 b'));
    });

    test('items text has one contiguous block per group, in order', () {
      final text = talkerLogItemsText(
        groupTalkerLogs(logs, const _CustomGrouper()),
        const _CustomGrouper(),
      );
      final lines = text.trim().split('\n');
      expect(lines.first, 'GROUP 1');
      expect(lines.last, contains('x'));
    });

    test('groupText throwing falls back to joined text', () {
      final item = groupTalkerLogs(logs, const _ThrowingGrouper()).first;
      final text = talkerLogItemText(item, const _ThrowingGrouper());
      expect(text, contains('#1 a'));
      expect(text, contains('#1 b'));
    });
  });

  group('TalkerView with grouper', () {
    late Talker talker;

    setUp(() {
      talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    });

    Future<void> pump(WidgetTester tester, TalkerLogGrouper? grouper) async {
      await tester.pumpWidget(MaterialApp(
        home: TalkerScreen(talker: talker, grouper: grouper),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('one card per group, pending group shown as group',
        (tester) async {
      talker.logCustom(TalkerLog('#1 req', key: 'http-request'));
      await pump(tester, const _IdGrouper());
      expect(find.byType(TalkerGroupCard), findsOneWidget);
      expect(find.byType(TalkerDataCard), findsNothing);
    });

    testWidgets('chip count matches what the chip filter shows',
        (tester) async {
      for (final id in ['1', '2', '3']) {
        talker.logCustom(TalkerLog('#$id req', key: 'http-request'));
        talker.logCustom(TalkerLog('#$id res', key: 'http-response'));
      }
      talker.logCustom(TalkerLog('#4 req', key: 'http-request'));
      await pump(tester, const _IdGrouper());

      Finder chip(String key) => find.ancestor(
            of: find.text(key),
            matching: find.byType(Row),
          );
      String count(String key) => tester
          .widget<Text>(
              find.descendant(of: chip(key), matching: find.byType(Text)).first)
          .data!;
      expect(count('http-request'), '1');
      expect(count('http-response'), '3');

      await tester.tap(find.text('http-request'));
      await tester.pumpAndSettle();
      expect(find.byType(TalkerGroupCard), findsOneWidget);
    });

    testWidgets('new log of a group updates the same card in place',
        (tester) async {
      talker.logCustom(TalkerLog('#1 req', key: 'http-request'));
      talker.logCustom(TalkerLog('#2 req', key: 'http-request'));
      await pump(tester, const _IdGrouper());
      final before = tester.getTopLeft(find.byType(TalkerGroupCard).last);
      final state = tester.state(find.byType(TalkerGroupCard).last);

      talker.logCustom(TalkerLog('#1 res', key: 'http-response'));
      await tester.pumpAndSettle();

      expect(find.byType(TalkerGroupCard), findsNWidgets(2));
      expect(tester.getTopLeft(find.byType(TalkerGroupCard).last), before);
      expect(tester.state(find.byType(TalkerGroupCard).last), same(state));
      expect(
        tester
            .widget<TalkerGroupCard>(find.byType(TalkerGroupCard).last)
            .group
            .logs,
        hasLength(2),
      );
    });

    testWidgets('custom buildGroup is used', (tester) async {
      talker.logCustom(TalkerLog('#7 req', key: 'http-request'));
      talker.logCustom(TalkerLog('#7 res', key: 'http-response'));
      await pump(tester, const _CustomGrouper());
      expect(find.text('custom 7 2'), findsOneWidget);
    });

    testWidgets('buildGroup throwing shows logs as single cards',
        (tester) async {
      talker.logCustom(TalkerLog('#1 req', key: 'http-request'));
      talker.logCustom(TalkerLog('#1 res', key: 'http-response'));
      await pump(tester, const _ThrowingGrouper());
      expect(tester.takeException(), isNull);
      expect(find.byType(TalkerDataCard), findsNWidgets(2));
    });

    testWidgets('without grouper every log is a TalkerDataCard',
        (tester) async {
      talker.logCustom(TalkerLog('#1 req', key: 'http-request'));
      talker.logCustom(TalkerLog('#1 res', key: 'http-response'));
      await pump(tester, null);
      expect(find.byType(TalkerGroupCard), findsNothing);
      expect(find.byType(TalkerDataCard), findsNWidgets(2));
    });
  });

  group('TalkerGroupCard', () {
    final group = TalkerLogGroup(key: '1', logs: [
      TalkerLog('#1 req', key: 'http-request', title: 'http-request'),
      TalkerLog('#1 err', key: 'http-error', title: 'http-error'),
    ]);
    const theme = TalkerScreenTheme();

    Future<void> pump(WidgetTester tester, {required bool expanded}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: TalkerGroupCard(
              group: group,
              theme: theme,
              expanded: expanded,
            ),
          ),
        ));

    testWidgets('shows first title, count, and last log color', (tester) async {
      await pump(tester, expanded: true);
      expect(find.textContaining('http-request |'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('http-error |'), findsOneWidget);

      final box = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(
          (box.border! as Border).top.color, group.last.getFlutterColor(theme));
    });

    testWidgets('collapsed hides log rows, tap expands', (tester) async {
      await pump(tester, expanded: false);
      expect(find.textContaining('http-error |'), findsNothing);
      await tester.tap(find.byType(TalkerGroupCard));
      await tester.pump();
      expect(find.textContaining('http-error |'), findsOneWidget);
    });
  });
}
