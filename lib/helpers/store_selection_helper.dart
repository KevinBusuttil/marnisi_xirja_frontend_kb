class StoreSelectionHelper {
  static List<String> buildStoreOptions(List<String> stores) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final store in stores) {
      final id = store.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      normalized.add(id);
    }

    return normalized;
  }

  static String? resolveSelectedStore({
    required List<String> storeOptions,
    String? preferredStoreId,
  }) {
    if (storeOptions.isEmpty) {
      return null;
    }
    if (preferredStoreId != null && storeOptions.contains(preferredStoreId)) {
      return preferredStoreId;
    }
    return storeOptions.first;
  }
}
