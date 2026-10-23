import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// UI view for output of all Talker logs and errors
class TalkerScreen extends StatelessWidget {
  const TalkerScreen({
    Key? key,
    required this.talker,
    this.appBarTitle = 'Talker',
    this.theme = const TalkerScreenTheme(),
    this.itemsBuilder,
    this.appBarLeading,
    this.customSettings = const [],
    this.isLogsExpanded = true,
    this.isLogOrderReversed = true,
    this.grouper,
    this.canShareLogsFile = true,
    this.filterKeys = const [],
    this.hiddenFilterKeys = const [],
  }) : super(key: key);

  /// Talker implementation
  final Talker talker;

  /// Theme for customize [TalkerScreen]
  final TalkerScreenTheme theme;

  /// Screen [AppBar] title
  final String appBarTitle;

  /// Screen [AppBar] leading
  final Widget? appBarLeading;

  /// Optional Builder to customize
  /// log items cards in list
  final TalkerDataBuilder? itemsBuilder;

  /// Optional custom settings
  final List<CustomSettingsGroup> customSettings;

  ///{@macro talker_flutter_is_log_exapanded}
  final bool isLogsExpanded;

  ///{@macro talker_flutter_is_log_order_reversed}
  final bool isLogOrderReversed;

  ///{@macro talker_flutter_grouper}
  final TalkerLogGrouper? grouper;

  ///{@macro talker_flutter_can_share_logs_file}
  final bool canShareLogsFile;

  ///{@macro talker_flutter_filter_keys}
  final List<String> filterKeys;

  ///{@macro talker_flutter_hidden_filter_keys}
  final List<String> hiddenFilterKeys;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: TalkerView(
        talker: talker,
        itemsBuilder: itemsBuilder,
        theme: theme,
        appBarTitle: appBarTitle,
        appBarLeading: appBarLeading,
        customSettings: customSettings,
        isLogsExpanded: isLogsExpanded,
        isLogOrderReversed: isLogOrderReversed,
        grouper: grouper,
        canShareLogsFile: canShareLogsFile,
        filterKeys: filterKeys,
        hiddenFilterKeys: hiddenFilterKeys,
      ),
    );
  }
}
