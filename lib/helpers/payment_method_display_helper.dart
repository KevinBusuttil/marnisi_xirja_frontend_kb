class PaymentMethodDisplayHelper {
  const PaymentMethodDisplayHelper._();

  static String resolveDisplayText(
    List<Map<String, dynamic>> paymentCache, {
    String fallback = '',
  }) {
    final seen = <String>{};
    final orderedNames = <String>[];

    for (final payment in paymentCache) {
      final rawName = (payment['pay_txn_name'] ?? '').toString().trim();
      if (rawName.isEmpty || !seen.add(rawName)) {
        continue;
      }
      orderedNames.add(rawName);
    }

    final resolved = orderedNames.join(', ').trim();
    if (resolved.isNotEmpty) {
      return resolved;
    }
    return fallback.trim();
  }
}
