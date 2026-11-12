import 'package:flutter/material.dart';

/// The daily "what will you focus on today?" notification. On at 6:00 AM by default.
class MorningReminder {
  const MorningReminder({
    this.enabled = true,
    this.time = const TimeOfDay(hour: 6, minute: 0),
  });

  final bool enabled;
  final TimeOfDay time;

  MorningReminder copyWith({bool? enabled, TimeOfDay? time}) => MorningReminder(
    enabled: enabled ?? this.enabled,
    time: time ?? this.time,
  );
}
