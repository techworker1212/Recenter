import 'package:flutter/material.dart';

import '../models/goal.dart';
import '../state/app_controller.dart';

/// Today's goals: add them, tick them off, delete them. The next unfinished goal also
/// appears with every interruption.
class GoalsSection extends StatefulWidget {
  const GoalsSection({super.key, required this.controller});

  final AppController controller;

  @override
  State<GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<GoalsSection> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _inputKey = GlobalKey();
  late int _seenFocusRequest;

  @override
  void initState() {
    super.initState();
    _seenFocusRequest = widget.controller.goalsFocusRequest;
    widget.controller.addListener(_onController);
    // Opened from the morning reminder on a cold start: the request is already waiting.
    if (_seenFocusRequest > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onController() {
    final request = widget.controller.goalsFocusRequest;
    if (request != _seenFocusRequest) {
      _seenFocusRequest = request;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput());
    }
  }

  /// The morning reminder was tapped: scroll to "Add a goal" and bring up the keyboard.
  void _focusInput() {
    if (!mounted) {
      return;
    }
    final target = _inputKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
    }
    _focus.requestFocus();
  }

  Future<void> _add() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      return;
    }
    _text.clear();
    await widget.controller.addGoal(text);
  }

  @override
  Widget build(BuildContext context) {
    final goals = widget.controller.goals;
    final done = goals.where((goal) => goal.done).length;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text("Today's goals", style: theme.textTheme.titleMedium),
            ),
            if (goals.isNotEmpty)
              Text(
                '$done of ${goals.length} done',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Your goals show up with every interruption. Press and hold the reminder to tick them off.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _MorningReminderTile(controller: widget.controller),
        Card(
          child: Column(
            children: [
              for (final goal in goals) _GoalTile(goal: goal, controller: widget.controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: _inputKey,
                        controller: _text,
                        focusNode: _focus,
                        maxLength: Goal.textMax,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _add(),
                        decoration: const InputDecoration(
                          hintText: 'Add a goal, like “Read 20 pages”',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add goal',
                      onPressed: _add,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Morning reminder · 6:00 AM": a switch to turn it off, tap to change the time.
class _MorningReminderTile extends StatelessWidget {
  const _MorningReminderTile({required this.controller});

  final AppController controller;

  Future<void> _pickTime(BuildContext context) async {
    final reminder = controller.morningReminder;
    final time = await showTimePicker(
      context: context,
      initialTime: reminder.time,
      helpText: 'Morning reminder',
    );
    if (time != null) {
      await controller.setMorningReminder(reminder.copyWith(time: time, enabled: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminder = controller.morningReminder;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.wb_twilight_outlined),
        title: const Text('Morning reminder'),
        subtitle: Text(
          reminder.enabled
              ? 'Every day at ${reminder.time.format(context)} · tap to change'
              : 'Off',
        ),
        onTap: () => _pickTime(context),
        trailing: Switch(
          value: reminder.enabled,
          onChanged: (enabled) =>
              controller.setMorningReminder(reminder.copyWith(enabled: enabled)),
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.controller});

  final Goal goal;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      value: goal.done,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (done) => controller.setGoalDone(goal, done ?? false),
      title: Text(
        goal.text,
        style: goal.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      secondary: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Remove goal',
        onPressed: () => controller.deleteGoal(goal),
      ),
    );
  }
}
