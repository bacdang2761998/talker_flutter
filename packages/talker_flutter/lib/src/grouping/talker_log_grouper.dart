import 'package:flutter/widgets.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Logs sharing the same [TalkerLogGrouper.groupKeyOf] key,
/// shown as a single item in [TalkerView]
class TalkerLogGroup {
  TalkerLogGroup({required this.key, required this.logs});

  final String key;

  /// Logs in chronological order
  final List<TalkerData> logs;

  TalkerData get first => logs.first;
  TalkerData get last => logs.last;
}

/// Decides which logs of [Talker.history] are grouped together
/// and how a group is displayed in [TalkerView]
abstract class TalkerLogGrouper {
  const TalkerLogGrouper();

  /// null = this log is not grouped
  String? groupKeyOf(TalkerData data);

  /// null = use default [TalkerGroupCard]
  Widget? buildGroup(
    BuildContext context,
    TalkerLogGroup group,
    TalkerScreenTheme theme,
  ) =>
      null;

  /// Text used for copy/share; joins text of the group logs by default
  String groupText(TalkerLogGroup group) =>
      group.logs.map((e) => e.generateTextMessage()).join('\n');
}

/// One item of [TalkerView] list: a single log or a group of logs
class TalkerLogItem {
  const TalkerLogItem.single(TalkerData this.data) : group = null;
  const TalkerLogItem.group(TalkerLogGroup this.group) : data = null;

  final TalkerData? data;
  final TalkerLogGroup? group;

  bool get isGroup => group != null;

  List<TalkerData> get logs => group?.logs ?? [data!];
}

/// Groups [history] (chronological order) by [grouper] in O(n).
/// A group takes the position of its first log.
/// Logs with a null key, or whose key can't be computed, stay single.
List<TalkerLogItem> groupTalkerLogs(
  List<TalkerData> history,
  TalkerLogGrouper grouper,
) {
  final items = <TalkerLogItem>[];
  final groups = <String, TalkerLogGroup>{};
  for (final data in history) {
    String? key;
    try {
      key = grouper.groupKeyOf(data);
    } catch (e) {
      debugPrint('TalkerLogGrouper.groupKeyOf failed: $e');
    }
    if (key == null) {
      items.add(TalkerLogItem.single(data));
      continue;
    }
    final existing = groups[key];
    if (existing != null) {
      existing.logs.add(data);
      continue;
    }
    final group = TalkerLogGroup(key: key, logs: [data]);
    groups[key] = group;
    items.add(TalkerLogItem.group(group));
  }
  return items;
}

/// Without [grouper] every log is a single item, as in upstream
List<TalkerLogItem> talkerLogItems(
  List<TalkerData> history,
  TalkerLogGrouper? grouper,
) {
  if (grouper == null) {
    return history.map(TalkerLogItem.single).toList();
  }
  return groupTalkerLogs(history, grouper);
}

/// A group is kept when at least one of its logs matches [filter],
/// and is then shown whole
List<TalkerLogItem> filterTalkerLogItems(
  List<TalkerLogItem> items,
  TalkerFilter filter,
) =>
    items.where((item) => item.logs.any(filter.filter)).toList();

/// Text of one item for copy/share
String talkerLogItemText(
  TalkerLogItem item,
  TalkerLogGrouper? grouper, {
  TimeFormat timeFormat = TimeFormat.timeAndSeconds,
}) {
  final group = item.group;
  if (group == null || grouper == null) {
    return item.logs
        .map((e) => e.generateTextMessage(timeFormat: timeFormat))
        .join('\n');
  }
  try {
    return grouper.groupText(group);
  } catch (e) {
    debugPrint('TalkerLogGrouper.groupText failed: $e');
    return group.logs
        .map((e) => e.generateTextMessage(timeFormat: timeFormat))
        .join('\n');
  }
}

/// Text of all [items] for copy/share/save; one contiguous block per item,
/// same layout as [TalkerDataInterfaceListExt.text]
String talkerLogItemsText(
  List<TalkerLogItem> items,
  TalkerLogGrouper? grouper, {
  TimeFormat timeFormat = TimeFormat.timeAndSeconds,
}) {
  final sb = StringBuffer();
  for (final item in items) {
    sb.write('${talkerLogItemText(item, grouper, timeFormat: timeFormat)}\n');
  }
  return sb.toString();
}
