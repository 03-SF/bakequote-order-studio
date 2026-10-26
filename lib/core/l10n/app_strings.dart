import 'package:flutter/widgets.dart';

/// English is the only supported application language.
class AppStrings {
  const AppStrings();
  static AppStrings of(BuildContext context) => const AppStrings();
  String t(String key) => key;
}
