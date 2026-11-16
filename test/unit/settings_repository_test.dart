import 'package:flutter_test/flutter_test.dart';
import 'package:javid_ai/data/repositories/settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  setUpAll(setUpSqfliteFfi);

  late TestDatabase database;
  late SettingsRepository repository;

  setUp(() async {
    database = await openCleanDatabase();
    repository = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('writes and reads a string', () async {
    await repository.write('ai_model', 'llama-3');
    expect(await repository.read('ai_model'), 'llama-3');
  });

  test('overwriting replaces the previous value', () async {
    await repository.write('theme_mode', 'dark');
    await repository.write('theme_mode', 'light');
    expect(await repository.read('theme_mode'), 'light');
  });

  test('booleans round-trip with a fallback for missing keys', () async {
    expect(await repository.readBool('missing', fallback: true), isTrue);
    await repository.writeBool('cloud_ai_enabled', false);
    expect(await repository.readBool('cloud_ai_enabled', fallback: true), isFalse);
  });

  test('readAll returns every stored key', () async {
    await repository.write('a', '1');
    await repository.write('b', '2');
    expect(await repository.readAll(), {'a': '1', 'b': '2'});
  });

  test('delete removes a key', () async {
    await repository.write('x', 'y');
    await repository.delete('x');
    expect(await repository.read('x'), isNull);
  });
}
