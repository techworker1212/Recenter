import 'package:flutter/material.dart';

import '../models/app_rule.dart';
import '../state/app_controller.dart';
import '../widgets/warning_preview.dart';

class RuleEditorScreen extends StatefulWidget {
  const RuleEditorScreen({
    super.key,
    required this.controller,
    this.existing,
  });

  final AppController controller;
  final AppRule? existing;

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  late final TextEditingController _label;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late int _limit;
  late int _unlock;
  late String _platformAppId;
  String? _pickedLabel;
  List<({String id, String label})> _installed = [];

  static const _presets = [
    (id: 'com.instagram.android', label: 'Instagram'),
    (id: 'com.zhiliaoapp.musically', label: 'TikTok'),
    (id: 'com.google.android.youtube', label: 'YouTube'),
    (id: 'com.twitter.android', label: 'X'),
    (id: 'com.facebook.katana', label: 'Facebook'),
    (id: 'com.reddit.frontpage', label: 'Reddit'),
    (id: 'com.snapchat.android', label: 'Snapchat'),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _label = TextEditingController(text: existing?.displayLabel ?? '');
    _title = TextEditingController(text: existing?.notificationTitle ?? '');
    _body = TextEditingController(text: existing?.notificationBody ?? '');
    _limit = existing?.limitMinutes ?? AppRule.defaultLimitMinutes;
    _unlock = existing?.unlockMinutes ?? AppRule.defaultUnlockMinutes;
    _platformAppId = existing?.platformAppId ?? '';
    _pickedLabel = existing?.displayLabel;
    _label.addListener(_rebuild);
    _title.addListener(_rebuild);
    _body.addListener(_rebuild);
    _loadInstalled();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadInstalled() async {
    if (!widget.controller.bridge.isAndroid) {
      return;
    }
    final apps = await widget.controller.bridge.installedApps();
    if (!mounted) {
      return;
    }
    setState(() {
      _installed = apps
          .map((app) => (id: app.packageId, label: app.label))
          .toList();
    });
  }

  AppRule get _draft {
    final existing = widget.existing;
    return AppRule(
      id:
          existing?.id ??
          'rule_${DateTime.now().microsecondsSinceEpoch}',
      platformAppId: _platformAppId,
      displayLabel: _label.text.trim().isEmpty
          ? (_pickedLabel ?? 'App')
          : _label.text.trim(),
      limitMinutes: _limit,
      unlockMinutes: _unlock,
      notificationTitle: _title.text,
      notificationBody: _body.text,
      enabled: existing?.enabled ?? true,
    );
  }

  Future<void> _pickIos() async {
    final token = await widget.controller.bridge.pickIosActivity();
    if (token.isEmpty) {
      return;
    }
    setState(() => _platformAppId = token);
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a label. iOS cannot reveal the real app name.'),
        ),
      );
      return;
    }
    if (_platformAppId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an app first.')),
      );
      return;
    }
    final failure = await widget.controller.upsertRule(_draft);
    if (!mounted) {
      return;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _label.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ios = widget.controller.bridge.isIos;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add app' : 'Edit app'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ios) ...[
            FilledButton.tonal(
              onPressed: _pickIos,
              child: Text(
                _platformAppId.isEmpty ? 'Pick app' : 'App selected — pick again',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Apple does not tell Recenter the app’s real name. Type a label such as Instagram.',
            ),
          ] else ...[
            Text('Presets', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: _presets
                  .map(
                    (preset) => ChoiceChip(
                      label: Text(preset.label),
                      selected: _platformAppId == preset.id,
                      onSelected: (_) {
                        setState(() {
                          _platformAppId = preset.id;
                          _pickedLabel = preset.label;
                          if (_label.text.isEmpty) {
                            _label.text = preset.label;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _installed.any((app) => app.id == _platformAppId)
                  ? _platformAppId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Installed apps',
                border: OutlineInputBorder(),
              ),
              items: _installed
                  .map(
                    (app) => DropdownMenuItem(
                      value: app.id,
                      child: Text(app.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                final match = _installed.firstWhere((app) => app.id == value);
                setState(() {
                  _platformAppId = value;
                  _pickedLabel = match.label;
                  if (_label.text.isEmpty) {
                    _label.text = match.label;
                  }
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Time limit: $_limit minutes'),
          Slider(
            min: 1,
            max: 60,
            divisions: 59,
            value: _limit.toDouble(),
            label: '$_limit min',
            onChanged: (value) => setState(() => _limit = value.round()),
          ),
          Text('Unlock for: $_unlock ${_unlock == 1 ? 'minute' : 'minutes'}'),
          Text(
            'How long "Unlock" on the pause screen opens this app before the next reminder.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Slider(
            min: 1,
            max: 15,
            divisions: 14,
            value: _unlock.toDouble(),
            label: '$_unlock min',
            onChanged: (value) => setState(() => _unlock = value.round()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            maxLength: AppRule.titleMax,
            decoration: const InputDecoration(
              labelText: 'Notification title',
              hintText: 'That’s enough TikTok',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            maxLength: AppRule.bodyMax,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notification body',
              hintText:
                  'You said you’d stop after 10 minutes. Unlock only if you still need it.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Five-second warning preview',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          WarningPreview(rule: _draft),
        ],
      ),
    );
  }
}
