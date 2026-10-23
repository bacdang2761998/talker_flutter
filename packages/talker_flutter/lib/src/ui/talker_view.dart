import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker_flutter/src/controller/controller.dart';
import 'package:talker_flutter/src/ui/talker_monitor/talker_monitor.dart';
import 'package:talker_flutter/src/ui/widgets/talker_view_appbar.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'talker_actions/talker_actions.dart';

class TalkerView extends StatefulWidget {
  const TalkerView({
    Key? key,
    required this.talker,
    this.controller,
    this.scrollController,
    this.theme = const TalkerScreenTheme(),
    this.appBarTitle,
    this.itemsBuilder,
    this.appBarLeading,
    this.customSettings = const [],
    this.isLogsExpanded = true,
    this.isLogOrderReversed = true,
    this.grouper,
    this.canShareLogsFile = true,
  }) : super(key: key);

  /// Talker implementation
  final Talker talker;

  /// Theme for customize [TalkerScreen]
  final TalkerScreenTheme theme;

  /// Screen [AppBar] title
  final String? appBarTitle;

  /// Screen [AppBar] leading
  final Widget? appBarLeading;

  /// Optional Builder to customize
  /// log items cards in list
  final TalkerDataBuilder? itemsBuilder;

  final TalkerViewController? controller;

  final ScrollController? scrollController;

  /// Optional custom settings
  final List<CustomSettingsGroup> customSettings;

  /// {@template talker_flutter_is_log_exapanded}
  /// If true, all logs will be initially expanded
  /// {@endtemplate}
  final bool isLogsExpanded;

  /// {@template talker_flutter_is_log_order_reversed}
  /// if true, latest logs will be on the top of the list
  /// {@endtemplate}
  final bool isLogOrderReversed;

  /// {@template talker_flutter_grouper}
  /// Groups logs into a single list item (e.g. request + response
  /// of one HTTP call). null = no grouping, same as upstream
  /// {@endtemplate}
  final TalkerLogGrouper? grouper;

  /// {@template talker_flutter_can_share_logs_file}
  /// false = hide the "Share logs file" action (logs never leave the device
  /// as a file). true = same as upstream
  /// {@endtemplate}
  final bool canShareLogsFile;

  @override
  State<TalkerView> createState() => _TalkerViewState();
}

class _TalkerViewState extends State<TalkerView> {
  late final _controller = widget.controller ??
      TalkerViewController(
        talker: widget.talker,
        expandedLogs: widget.isLogsExpanded,
        isLogOrderReversed: widget.isLogOrderReversed,
      );

  @override
  Widget build(BuildContext context) {
    final talkerTheme = widget.theme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return TalkerBuilder(
            talker: widget.talker,
            builder: (context, data) {
              final items = talkerLogItems(data, widget.grouper);
              final filteredElements =
                  filterTalkerLogItems(items, _controller.filter);
              // Counts follow the key filter: one per item, by its last log
              final keys = talkerLogItemKeys(items);
              final uniqKeys = data.map((e) => e.key).toSet().toList();

              return CustomScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  TalkerViewAppBar(
                    keys: keys,
                    uniqKeys: uniqKeys,
                    title: widget.appBarTitle,
                    leading: widget.appBarLeading,
                    talker: widget.talker,
                    talkerTheme: talkerTheme,
                    controller: _controller,
                    onMonitorTap: () => _openTalkerMonitor(context),
                    onActionsTap: () => _openActions(context),
                    onSettingsTap: () => _openSettings(context, talkerTheme),
                    onToggleKey: _onToggleKey,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final item = _getListItem(filteredElements, i);
                        if (item.group != null) {
                          return _buildGroup(context, item.group!);
                        }
                        final data = item.data!;
                        if (widget.itemsBuilder != null) {
                          return widget.itemsBuilder!.call(context, data);
                        }
                        return TalkerDataCard(
                          data: data,
                          backgroundColor: widget.theme.cardColor,
                          onCopyTap: () => _copyTalkerDataItemText(data),
                          expanded: _controller.expandedLogs,
                          color: data.getFlutterColor(widget.theme),
                        );
                      },
                      childCount: filteredElements.length,
                      findChildIndexCallback: (key) =>
                          _findItemIndex(filteredElements, key),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<TalkerData> _getFilteredLogs(List<TalkerData> data) =>
      data.where((e) => _controller.filter.filter(e)).toList();

  List<TalkerLogItem> _getFilteredItems(List<TalkerData> data) =>
      filterTalkerLogItems(
          talkerLogItems(data, widget.grouper), _controller.filter);

  /// Keeps a group card at its position (and state) when a new log
  /// of the group arrives
  int? _findItemIndex(List<TalkerLogItem> items, Key key) {
    if (key is! ValueKey<String>) return null;
    final index = items.indexWhere((e) => e.group?.key == key.value);
    if (index < 0) return null;
    return _controller.isLogOrderReversed ? items.length - 1 - index : index;
  }

  Widget _buildGroup(BuildContext context, TalkerLogGroup group) {
    Widget? child;
    try {
      child = widget.grouper!.buildGroup(context, group, widget.theme);
    } catch (e) {
      debugPrint('TalkerLogGrouper.buildGroup failed: $e');
      child = Column(
        children: group.logs
            .map((data) => TalkerDataCard(
                  data: data,
                  backgroundColor: widget.theme.cardColor,
                  onCopyTap: () => _copyTalkerDataItemText(data),
                  expanded: _controller.expandedLogs,
                  color: data.getFlutterColor(widget.theme),
                ))
            .toList(),
      );
    }
    return KeyedSubtree(
      key: ValueKey<String>(group.key),
      child: child ??
          TalkerGroupCard(
            group: group,
            theme: widget.theme,
            expanded: _controller.expandedLogs,
            onCopyTap: () => _copyText(
              talkerLogItemText(TalkerLogItem.group(group), widget.grouper),
            ),
          ),
    );
  }

  void _onToggleKey(String key, bool selected) {
    final action =
        selected ? _controller.addFilterKey : _controller.removeFilterKey;
    action(key);
  }

  TalkerLogItem _getListItem(
    List<TalkerLogItem> filteredElements,
    int i,
  ) {
    final data = filteredElements[
        _controller.isLogOrderReversed ? filteredElements.length - 1 - i : i];
    return data;
  }

  void _openSettings(BuildContext context, TalkerScreenTheme theme) {
    final talker = ValueNotifier(widget.talker);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return TalkerSettingsBottomSheet(
          talkerScreenTheme: theme,
          talker: talker,
          customSettings: widget.customSettings,
        );
      },
    );
  }

  void _openTalkerMonitor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TalkerMonitor(
          theme: widget.theme,
          talker: widget.talker,
        ),
      ),
    );
  }

  void _copyTalkerDataItemText(TalkerData data) {
    final text =
        data.generateTextMessage(timeFormat: widget.talker.settings.timeFormat);
    _copyText(text);
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, 'Log item is copied in clipboard');
  }

  /// Text of [logs] for copy/share; one block per group when grouping
  String _logsText(List<TalkerData> logs) {
    final timeFormat = widget.talker.settings.timeFormat;
    if (widget.grouper == null) return logs.text(timeFormat: timeFormat);
    return talkerLogItemsText(
      groupTalkerLogs(logs, widget.grouper!),
      widget.grouper,
      timeFormat: timeFormat,
    );
  }

  void _showSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openActions(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return TalkerActionsBottomSheet(
          actions: [
            TalkerActionItem(
              onTap: _controller.toggleLogOrder,
              title: 'Reverse logs',
              icon: Icons.swap_vert,
            ),
            TalkerActionItem(
              onTap: () => _copyAllLogs(context),
              title: 'Copy all logs',
              icon: Icons.copy,
            ),
            TalkerActionItem(
              onTap: () => _copyFilteredLogs(context),
              title: 'Copy filtered logs',
              icon: Icons.copy,
            ),
            TalkerActionItem(
              onTap: _toggleLogsExpanded,
              title: _controller.expandedLogs ? 'Collapse logs' : 'Expand logs',
              icon: _controller.expandedLogs
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            TalkerActionItem(
              onTap: _cleanHistory,
              title: 'Clean history',
              icon: Icons.delete_outline,
            ),
            if (widget.canShareLogsFile)
              TalkerActionItem(
                onTap: _shareLogsInFile,
                title: 'Share logs file',
                icon: Icons.ios_share_outlined,
              ),
          ],
          talkerScreenTheme: widget.theme,
        );
      },
    );
  }

  Future<void> _shareLogsInFile() async {
    await _controller.downloadLogsFile(_logsText(widget.talker.history));
  }

  void _cleanHistory() {
    widget.talker.cleanHistory();
    _controller.update();
  }

  void _toggleLogsExpanded() {
    _controller.toggleExpandedLogs();
  }

  void _copyAllLogs(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _logsText(widget.talker.history)));
    _showSnackBar(context, 'All logs copied in buffer');
  }

  void _copyFilteredLogs(BuildContext context) {
    final text = widget.grouper == null
        ? _logsText(_getFilteredLogs(widget.talker.history))
        : talkerLogItemsText(
            _getFilteredItems(widget.talker.history), widget.grouper,
            timeFormat: widget.talker.settings.timeFormat);
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar(context, 'All filtered logs copied in buffer');
  }
}
