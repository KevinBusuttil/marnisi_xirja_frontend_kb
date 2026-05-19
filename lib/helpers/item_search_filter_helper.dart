class ItemSearchFilterHelper {
  const ItemSearchFilterHelper._();

  static List<Map<String, dynamic>> filterSalesItems({
    required List<Map<String, dynamic>> items,
    required String searchTerm,
  }) {
    final token = searchTerm.trim().toLowerCase();
    if (token.isEmpty) {
      return List<Map<String, dynamic>>.from(items);
    }

    return items.where((item) {
      final barcode = (item['item_barcode'] ?? '').toString().toLowerCase();
      final name = (item['item_name'] ?? '').toString().toLowerCase();
      return barcode.contains(token) || name.contains(token);
    }).toList(growable: false);
  }
}
