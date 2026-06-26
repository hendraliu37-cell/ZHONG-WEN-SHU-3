import 'package:flutter/material.dart';
import 'tokens.dart';

/// Exposes the active [ZwsTokens] to the whole subtree. Read with
/// `ZwsTheme.of(context)`.
class ZwsTheme extends InheritedWidget {
  final ZwsTokens tokens;
  const ZwsTheme({super.key, required this.tokens, required super.child});

  static ZwsTokens of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<ZwsTheme>();
    assert(w != null, 'ZwsTheme not found in context');
    return w!.tokens;
  }

  @override
  bool updateShouldNotify(ZwsTheme oldWidget) => oldWidget.tokens != tokens;
}

/// Resolve tokens from the controller's themeMode + platform brightness.
ZwsTokens resolveTokens(String themeMode, Brightness platform) {
  final dark = themeMode == 'dark' ||
      (themeMode == 'system' && platform == Brightness.dark);
  return dark ? ZwsTokens.dark : ZwsTokens.light;
}
