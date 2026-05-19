import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/store_selection_helper.dart';

void main() {
  group('StoreSelectionHelper.buildStoreOptions', () {
    test('removes empty and duplicate store ids while preserving order', () {
      final options = StoreSelectionHelper.buildStoreOptions([
        '',
        'store-local',
        'paola',
        'store-local',
        '  ',
        'gzira',
      ]);

      expect(options, ['store-local', 'paola', 'gzira']);
    });
  });

  group('StoreSelectionHelper.resolveSelectedStore', () {
    test('keeps preferred store when it exists in options', () {
      final selected = StoreSelectionHelper.resolveSelectedStore(
        storeOptions: ['paola', 'gzira'],
        preferredStoreId: 'gzira',
      );

      expect(selected, 'gzira');
    });

    test('falls back to first option when preferred store is missing', () {
      final selected = StoreSelectionHelper.resolveSelectedStore(
        storeOptions: ['paola', 'gzira'],
        preferredStoreId: 'unknown',
      );

      expect(selected, 'paola');
    });

    test('returns null when options are empty', () {
      final selected = StoreSelectionHelper.resolveSelectedStore(
        storeOptions: const [],
        preferredStoreId: 'paola',
      );

      expect(selected, isNull);
    });
  });
}
