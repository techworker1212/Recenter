import 'package:flutter/material.dart';

import '../models/app_rule.dart';
import '../screens/rule_editor_screen.dart';
import '../state/app_controller.dart';
import '../widgets/goals_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Recenter'),
            actions: [
              _ThemeToggle(controller: controller),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Add app'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Monitoring'),
                subtitle: Text(
                  controller.settings.monitoringEnabled
                      ? 'Watching selected apps'
                      : 'Paused',
                ),
                value: controller.settings.monitoringEnabled,
                onChanged: controller.setMonitoring,
              ),
              if (controller.missingPermissions.isNotEmpty)
                _PermissionBanner(controller: controller),
              const SizedBox(height: 8),
              _InterruptionsCard(controller: controller),
              const SizedBox(height: 16),
              GoalsSection(controller: controller),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Text('App rules', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (controller.rules.isEmpty)
                const Text(
                  'Add an app, set a time limit, and write the reminder you want to see when time is up.',
                ),
              ...controller.rules.map((rule) => _RuleTile(
                    rule: rule,
                    onEdit: () => _openEditor(context, rule: rule),
                    onToggle: (enabled) =>
                        controller.setRuleEnabled(rule, enabled),
                    onDelete: () => _confirmDelete(context, rule),
                  )),
              const SizedBox(height: 72),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${rule.displayLabel}?'),
        content: const Text('Its limit and reminder will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteRule(rule.id);
    }
  }

  Future<void> _openEditor(BuildContext context, {AppRule? rule}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RuleEditorScreen(controller: controller, existing: rule),
      ),
    );
  }
}

/// Switches between light and dark. Shows the mode you'll switch *to*.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return IconButton(
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => controller.toggleTheme(brightness),
    );
  }
}

/// Today's total; tap to see how many times each app was interrupted.
class _InterruptionsCard extends StatelessWidget {
  const _InterruptionsCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final labels = {for (final rule in controller.rules) rule.id: rule.displayLabel};
    final perApp = controller.interruptionsByRule.entries
        .where((entry) => entry.value > 0)
        .map((entry) => (label: labels[entry.key] ?? 'Removed app', count: entry.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text('${controller.interruptionsToday}'),
        subtitle: const Text('Interruptions today'),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: perApp.isEmpty
            ? const [
                ListTile(
                  dense: true,
                  title: Text('No interruptions yet today.'),
                ),
              ]
            : [
                for (final app in perApp)
                  ListTile(
                    dense: true,
                    title: Text(app.label),
                    trailing: Text(
                      '${app.count}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.controller});

  final AppController controller;

  static const _labels = {
    'familyControls': 'Screen Time access',
    'usageAccess': 'Usage access',
    'notifications': 'Notifications',
    'overlay': 'Display over other apps',
  };

  @override
  Widget build(BuildContext context) {
    final missing = controller.missingPermissions;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recenter needs a few permissions to work',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: missing
                  .map(
                    (kind) => ActionChip(
                      avatar: const Icon(Icons.lock_open, size: 18),
                      label: Text(_labels[kind] ?? kind),
                      onPressed: controller.busy
                          ? null
                          : () => controller.requestPermission(kind),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AppRule rule;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(rule.displayLabel),
        subtitle: Text(
          '${rule.limitMinutes} min a day\n“${rule.resolvedTitle}”',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        onTap: onEdit,
        onLongPress: onDelete,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: rule.enabled, onChanged: onToggle),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
