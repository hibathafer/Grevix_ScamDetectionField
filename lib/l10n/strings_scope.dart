import 'package:flutter/widgets.dart';

import 'app_strings.dart';

/// Provides the active [AppStrings] to the whole tree and lets any descendant
/// switch language.
///
/// Placed above [MaterialApp], so pushed routes (the result screen) can read
/// it too. Changing [strings] rebuilds the app immediately — no restart.
class StringsScope extends InheritedWidget {
  const StringsScope({
    super.key,
    required this.strings,
    required this.onChanged,
    required super.child,
  });

  final AppStrings strings;

  /// Requests a language change with a fully-formed strings object.
  final ValueChanged<AppStrings> onChanged;

  /// The active language. Throws if used above a [StringsScope].
  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StringsScope>();
    assert(
      scope != null,
      'StringsScope.of() was called outside a StringsScope widget.',
    );
    return scope!.strings;
  }

  /// Non-listening lookup, for callbacks that only need to change language.
  static AppStrings read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StringsScope>();
    assert(
      scope != null,
      'StringsScope.read() was called outside a StringsScope widget.',
    );
    return scope!.strings;
  }

  /// Requests a language change without registering a dependency, so it is
  /// safe to call from a tap handler.
  static void requestChange(BuildContext context, AppStrings next) {
    final scope = context.findAncestorWidgetOfExactType<StringsScope>();
    assert(
      scope != null,
      'StringsScope.requestChange() was called outside a StringsScope widget.',
    );
    scope!.onChanged(next);
  }

  @override
  bool updateShouldNotify(StringsScope oldWidget) =>
      strings.languageCode != oldWidget.strings.languageCode;
}
