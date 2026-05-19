import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/settings_selection_helper.dart';

void main() {
  group('SettingsSelectionHelper.resolveSelectedStore', () {
    test('prefers primary key when available', () {
      final value = SettingsSelectionHelper.resolveSelectedStore(
        primaryValue: 'STRGzira',
        legacyValue: 'store-local',
      );

      expect(value, 'STRGzira');
    });

    test('falls back to legacy key when primary is empty', () {
      final value = SettingsSelectionHelper.resolveSelectedStore(
        primaryValue: '',
        legacyValue: 'STRPaola',
      );

      expect(value, 'STRPaola');
    });
  });

  group('SettingsSelectionHelper.resolveSelectedRegister', () {
    test('prefers primary key when available', () {
      final value = SettingsSelectionHelper.resolveSelectedRegister(
        primaryValue: 'REGGzira01',
        legacyValue: 'register-local-001',
      );

      expect(value, 'REGGzira01');
    });

    test('returns empty when both keys are empty', () {
      final value = SettingsSelectionHelper.resolveSelectedRegister(
        primaryValue: '',
        legacyValue: '',
      );

      expect(value, '');
    });
  });
}
