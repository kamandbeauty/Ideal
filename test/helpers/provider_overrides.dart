import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:javid_ai/core/providers/database_provider.dart';
import 'package:javid_ai/data/local/app_database.dart';

/// Provides an already-opened test database to the provider graph.
Override appDatabaseProviderOverride(AppDatabase database) =>
    appDatabaseProvider.overrideWithValue(database);
