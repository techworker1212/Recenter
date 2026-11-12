import 'dart:io';

import 'package:flutter/material.dart';

import '../state/app_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  List<_OnboardingPage> get _pages {
    if (Platform.isIOS) {
      return const [
        _OnboardingPage(
          title: 'Recenter pauses one app at a time',
          body: 'When a selected app hits its limit, iOS shows your custom reminder for five seconds, then a Screen Time shield. Recenter cannot lock the whole phone.',
          kind: null,
        ),
        _OnboardingPage(
          title: 'Screen Time access',
          body: 'Family Controls lets Recenter watch only the apps you pick and shield them when time is up. This stays on your device.',
          kind: 'familyControls',
        ),
        _OnboardingPage(
          title: 'Notifications',
          body: 'The five-second warning uses a local notification with the title and body you wrote for that app.',
          kind: 'notifications',
        ),
      ];
    }
    return const [
      _OnboardingPage(
        title: 'Recenter pauses one app at a time',
        body: 'When a selected app hits its limit, Android shows your custom reminder for five seconds, then a full-screen pause. Recenter cannot lock the hardware lock screen.',
        kind: null,
      ),
      _OnboardingPage(
        title: 'Usage access',
        body: 'Recenter reads which app is in the foreground so it can apply that app’s limit. Usage data never leaves this device. This is not an accessibility tool.',
        kind: 'usageAccess',
      ),
      _OnboardingPage(
        title: 'Notifications',
        body: 'The five-second warning is a notification that uses the custom title and body you set for that app.',
        kind: 'notifications',
      ),
      _OnboardingPage(
        title: 'Display over other apps',
        body: 'Needed so the pause screen can appear over Instagram, TikTok, and other apps after the warning. You can deny this and Recenter will still try a full-screen notification.',
        kind: 'overlay',
      ),
      _OnboardingPage(
        title: 'Keep Recenter running',
        body: 'Some phones stop background apps to save battery. Choose "Don\u2019t optimize" for Recenter so limits keep working after a while.',
        kind: 'battery',
      ),
    ];
  }

  Future<void> _next() async {
    final pages = _pages;
    final current = pages[_page];
    if (current.kind != null) {
      await widget.controller.requestPermission(current.kind!);
    }
    if (_page >= pages.length - 1) {
      await widget.controller.completeOnboarding();
      return;
    }
    setState(() => _page += 1);
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recenter',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Text(
                page.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(page.body, style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.controller.busy ? null : _next,
                  child: Text(
                    page.kind == null
                        ? 'Continue'
                        : _page == _pages.length - 1
                        ? 'Finish'
                        : 'Allow and continue',
                  ),
                ),
              ),
              if (page.kind != null)
                TextButton(
                  onPressed: widget.controller.busy
                      ? null
                      : () {
                          if (_page >= _pages.length - 1) {
                            widget.controller.completeOnboarding();
                          } else {
                            setState(() => _page += 1);
                          }
                        },
                  child: const Text('Skip for now'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.title,
    required this.body,
    required this.kind,
  });

  final String title;
  final String body;
  final String? kind;
}
