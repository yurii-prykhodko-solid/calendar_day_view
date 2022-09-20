import 'dart:async';

import 'package:flutter/material.dart';

import 'package:calendar_day_view/src/utils.dart';

import 'day_event.dart';
import 'widgets/current_time_line_widget.dart';

typedef DayViewItemBuilder<T extends Object> = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
  DayEvent<T> event,
);

typedef DayViewTimeRowBuilder<T extends Object> = Widget Function(
  BuildContext,
  BoxConstraints constraints,
  List<DayEvent<T>>,
);

/// Show events in a time gap window in a single row
///
/// ex: if [timeGap] is 15, the events that have start time from `10:00` to `10:15`
/// will be displayed in the same row.
class InRowCalendarDayView<T extends Object> extends StatefulWidget {
  const InRowCalendarDayView({
    Key? key,
    required this.events,
    this.startOfDay = const TimeOfDay(hour: 8, minute: 0),
    this.endOfDay,
    this.showWithEventOnly = false,
    this.timeGap = 60,
    this.timeTextColor,
    this.timeTextStyle,
    this.itemBuilder,
    this.dividerColor,
    this.timeRowBuilder,
    this.heightPerMin = 2.0,
    this.showCurrentTimeLine = false,
    this.currentTimeLineColor,
  })  : assert(timeRowBuilder != null || itemBuilder != null),
        assert(timeRowBuilder == null || itemBuilder == null),
        super(key: key);

  /// To show a line that indicate current hour and minute;
  final bool showCurrentTimeLine;

  /// Color of the current time line
  final Color? currentTimeLineColor;

  /// height in pixel per minute
  final double heightPerMin;

  /// List of events to be display in the day view
  final List<DayEvent<T>> events;

  /// To set the start time of the day view
  final TimeOfDay startOfDay;

  /// To set the end time of the day view
  final TimeOfDay? endOfDay;

  /// if true, only display row with events. Default to false
  final bool showWithEventOnly;

  /// time gap/duration of a row.
  final int timeGap;

  /// color of time point label
  final Color? timeTextColor;

  /// style of time point label
  final TextStyle? timeTextStyle;

  /// time slot divider color
  final Color? dividerColor;

  /// builder for single item in a time row
  final DayViewItemBuilder<T>? itemBuilder;

  /// builder for single time row (this and [itemBuilder] can not exist at the same time)
  final DayViewTimeRowBuilder<T>? timeRowBuilder;

  @override
  State<InRowCalendarDayView> createState() => _InRowCalendarDayViewState<T>();
}

class _InRowCalendarDayViewState<T extends Object>
    extends State<InRowCalendarDayView<T>> {
  List<TimeOfDay> _timesInDay = [];
  double _heightPerMin = 1;
  TimeOfDay _currentTime = TimeOfDay.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _heightPerMin = widget.heightPerMin;
    _timesInDay = getTimeList();

    if (widget.showCurrentTimeLine) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        setState(() {
          _currentTime = TimeOfDay.now();
        });
      });
    }
  }

  List<TimeOfDay> getTimeList() {
    final timeEnd = widget.endOfDay ?? const TimeOfDay(hour: 23, minute: 0);

    final timeCount =
        ((timeEnd.hour - widget.startOfDay.hour) * 60) ~/ widget.timeGap;
    DateTime first = DateTime.parse(
        "2012-02-27T${widget.startOfDay.hour.toString().padLeft(2, '0')}:00");
    List<TimeOfDay> list = [];
    for (var i = 1; i <= timeCount; i++) {
      list.add(TimeOfDay.fromDateTime(first));
      first = first.add(Duration(minutes: widget.timeGap));
    }
    return list;
  }

  @override
  void didUpdateWidget(covariant InRowCalendarDayView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if (widget.timeGap != oldWidget.timeGap) {
    setState(() {
      _timesInDay = getTimeList();
      _heightPerMin = widget.heightPerMin;
    });
    // }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double rowHeight = widget.timeGap * _heightPerMin;
      final viewWidth = constraints.maxWidth;

      return SafeArea(
        child: GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              _heightPerMin = (_heightPerMin * details.scale)
                  .clamp(widget.heightPerMin, widget.heightPerMin * 5);
            });
          },
          child: ListView(
            // clipBehavior: Clip.none,
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            children: _timesInDay.map(
              (time) {
                final events = widget.events.where(
                  (event) => event.isInThisGap(time, widget.timeGap),
                );

                if (events.isEmpty && widget.showWithEventOnly) {
                  return const SizedBox.shrink();
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: rowHeight,
                    maxHeight: rowHeight,
                    maxWidth: viewWidth,
                  ),
                  child: Stack(
                    // clipBehavior: Clip.none,
                    // fit: StackFit.expand,
                    children: [
                      Divider(
                        color: widget.dividerColor ?? Colors.amber,
                        height: 0,
                        thickness: time.minute == 0 ? 1 : .5,
                        indent: 50,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform(
                            transform: Matrix4.translationValues(0, -10, 0),
                            child: SizedBox(
                              width: 50,
                              child: Text(
                                "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, "0")}",
                                style: widget.timeTextStyle ??
                                    TextStyle(color: widget.timeTextColor),
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constrains) {
                                return SizedBox(
                                  height: rowHeight,
                                  child: Builder(
                                    builder: (context) {
                                      if (widget.timeRowBuilder != null) {
                                        return widget.timeRowBuilder!(
                                          context,
                                          constrains,
                                          events.toList(),
                                        );
                                      } else {
                                        return Row(
                                          children: [
                                            for (final event in events)
                                              widget.itemBuilder!(
                                                context,
                                                constrains,
                                                event,
                                              )
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      if (widget.showCurrentTimeLine &&
                          inTheGap(_currentTime, time, widget.timeGap))
                        CurrentTimeLineWidget(
                          top: (_currentTime.minute - time.minute) *
                              _heightPerMin,
                          color: widget.currentTimeLineColor,
                          width: viewWidth,
                        ),
                    ],
                  ),
                );
              },
            ).toList(),
          ),
        ),
      );
    });
  }
}
