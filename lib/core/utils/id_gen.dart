import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a time-ordered, URL-safe identifier (UUID v7).
///
/// Time-ordered ids keep SQLite B-tree inserts cheap and make "newest first"
/// listings stable even when two rows share a millisecond timestamp.
String newId() => _uuid.v7();
