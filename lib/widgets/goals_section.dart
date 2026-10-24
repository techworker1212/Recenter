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

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
                        controller: _text,
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
