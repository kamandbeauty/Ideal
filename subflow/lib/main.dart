import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// SubFlow entry point.
///
/// Nothing heavy happens here: the database is opened lazily by the providers
/// and every AI / media operation runs on the native side, never on the UI
/// isolate (non-negotiable #1..#4 of the product brief).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SubFlowApp()));
}
