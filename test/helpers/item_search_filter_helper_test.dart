import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/item_search_filter_helper.dart';

void main() {
  group('ItemSearchFilterHelper.filterSalesItems', () {
    final items = <Map<String, dynamic>>[
      {
        'item_barcode': 'FMW100001',
        'item_name': '100th Anniversary 0.75L',
      },
      {
        'item_barcode': 'FMWANT012',
        'item_name': 'Antonin Blanc 1.5L',
      },
    ];

    test('returns all items when search term is empty', () {
      final filtered = ItemSearchFilterHelper.filterSalesItems(
        items: items,
        searchTerm: '',
      );

      expect(filtered.length, 2);
      expect(filtered.first['item_barcode'], 'FMW100001');
    });

    test('matches barcode and name case-insensitively', () {
      final byCode = ItemSearchFilterHelper.filterSalesItems(
        items: items,
        searchTerm: 'fmwant',
      );
      final byName = ItemSearchFilterHelper.filterSalesItems(
        items: items,
        searchTerm: 'anniversary',
      );

      expect(byCode.length, 1);
      expect(byCode.first['item_name'], 'Antonin Blanc 1.5L');
      expect(byName.length, 1);
      expect(byName.first['item_barcode'], 'FMW100001');
    });
  });
}
