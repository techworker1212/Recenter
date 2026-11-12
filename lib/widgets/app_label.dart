import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_rule.dart';

/// The app a rule watches: on iOS its real icon and name, drawn by iOS (Apple never tells
/// Recenter what was picked); on Android the app's name, which Android does share.
class AppLabel extends StatelessWidget {
  const AppLabel({
    super.key,
    required this.selection,
    required this.fallback,
    this.iconOnly = false,
    this.style,
    this.height = 28,
  });

  AppLabel.forRule(
    AppRule rule, {
    Key? key,
    TextStyle? style,
    double height = 28,
  }) : this(
         key: key,
         selection: rule.platformAppId,
         fallback: rule.displayLabel,
         style: style,
         height: height,
       );

  final String selection;
  final String fallback;
  final bool iconOnly;
  final TextStyle? style;
  final double height;

  static bool get _onIos => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.titleMedium!;
    if (!_onIos || selection.isEmpty) {
      return Text(
        fallback,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final color = textStyle.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: height,
      width: iconOnly ? height : double.infinity,
      // Taps go to the row around it.
      child: IgnorePointer(
        child: UiKitView(
          // A new view when the selection or colours change (e.g. the theme switch).
          key: ValueKey('$selection|${color.toARGB32()}|$iconOnly'),
          viewType: 'recenter/app-label',
          creationParams: {
            'selection': selection,
            'fallback': fallback,
            'style': iconOnly ? 'iconOnly' : 'titleAndIcon',
            'fontSize': textStyle.fontSize ?? 16,
            'color': color.toARGB32(),
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
