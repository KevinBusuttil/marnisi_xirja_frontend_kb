class MarnisiPosRestrictions {
  static const bool hideTourManagementMenu = true;
  static const bool hideTourListButton = true;
  static const bool hideDiscountButton = true;
  static const bool hideGiftReceiptAction = true;
  static const bool lockStoreAndRegisterSelection = true;
  static const String lockedStoreId = "Marnisi M'Xlokk";
  static const String lockedRegisterId = "$lockedStoreId-MAIN";

  static const Set<String> _hiddenPaymentMethodIds = {
    '1', // Cash
    '2', // Cheque BOV
    '8', // Other Cheque
    '10', // Staff Voucher
    '9', // Gift Card
    '12', // Stripe
    '3', // On Account
    '13', // Bank Transfer
  };

  static bool showPaymentMethod(String paymentMethodId) {
    return !_hiddenPaymentMethodIds.contains(paymentMethodId);
  }

  static List<String> restrictStoreOptions(List<String> stores) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in stores) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      normalized.add(value);
    }

    if (!lockStoreAndRegisterSelection) {
      return normalized;
    }

    if (normalized.contains(lockedStoreId)) {
      return [lockedStoreId];
    }

    if (normalized.isNotEmpty) {
      return [normalized.first];
    }

    return const [];
  }

  static List<String> restrictRegisterOptions(List<String> registers) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in registers) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      normalized.add(value);
    }

    if (!lockStoreAndRegisterSelection) {
      return normalized;
    }

    if (normalized.contains(lockedRegisterId)) {
      return [lockedRegisterId];
    }

    if (normalized.isNotEmpty) {
      return [normalized.first];
    }

    return const [];
  }
}
