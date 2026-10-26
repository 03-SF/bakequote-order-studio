import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/auth/application/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Capture the web callback before go_router removes sensitive query parameters.
  final initialUri = Uri.base;
  runApp(
    ProviderScope(
      overrides: [
        if (kIsWeb)
          initialAuthLinkProvider.overrideWithValue(Future.value(initialUri)),
      ],
      child: const BakeQuoteApp(),
    ),
  );
}
