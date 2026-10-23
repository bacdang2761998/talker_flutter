import 'package:flutter/material.dart';
import 'package:talker_flutter/src/ui/widgets/base_card.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Default card of a [TalkerLogGroup]: title of the first log,
/// number of logs and the collapsed list of the group logs.
/// Border color follows the last log.
class TalkerGroupCard extends StatefulWidget {
  const TalkerGroupCard({
    Key? key,
    required this.group,
    required this.theme,
    this.onCopyTap,
    this.onTap,
    this.expanded = true,
    this.margin,
  }) : super(key: key);

  final TalkerLogGroup group;
  final TalkerScreenTheme theme;
  final VoidCallback? onCopyTap;
  final VoidCallback? onTap;
  final bool expanded;
  final EdgeInsets? margin;

  @override
  State<TalkerGroupCard> createState() => _TalkerGroupCardState();
}

class _TalkerGroupCardState extends State<TalkerGroupCard> {
  var _expanded = false;

  @override
  void initState() {
    _expanded = widget.expanded;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TalkerGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      _expanded = widget.expanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final color = group.last.getFlutterColor(widget.theme);
    return Padding(
      padding: widget.margin ?? const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _onTap,
        child: TalkerBaseCard(
          color: color,
          backgroundColor: widget.theme.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${group.first.title} | ${group.first.displayTime()}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      border: Border.all(color: color),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${group.logs.length}',
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: Icon(Icons.copy, color: color),
                      onPressed: widget.onCopyTap,
                    ),
                  ),
                ],
              ),
              Text(
                group.first.displayMessage,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12),
              ),
              if (_expanded)
                for (final log in group.logs) _GroupLogRow(log, widget.theme),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap() {
    if (widget.onTap != null) {
      widget.onTap?.call();
      return;
    }
    setState(() => _expanded = !_expanded);
  }
}

class _GroupLogRow extends StatelessWidget {
  const _GroupLogRow(this.data, this.theme);

  final TalkerData data;
  final TalkerScreenTheme theme;

  @override
  Widget build(BuildContext context) {
    final color = data.getFlutterColor(theme);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 6, top: 1),
            color: color,
          ),
          Expanded(
            child: Text(
              '${data.title} | ${data.displayTime()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
