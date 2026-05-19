import 'package:web_admin/constants/shared_values.dart';

class SettingsSelectionHelper {
  static const String legacySelectedStoreKey = 'selectedStore';
  static const String legacySelectedRegisterKey = 'selectedRegister';

  static String resolveSelectedStore({
    String? primaryValue,
    String? legacyValue,
  }) {
    final primary = (primaryValue ?? '').trim();
    if (primary.isNotEmpty) {
      return primary;
    }

    final legacy = (legacyValue ?? '').trim();
    if (legacy.isNotEmpty) {
      return legacy;
    }

    return '';
  }

  static String resolveSelectedRegister({
    String? primaryValue,
    String? legacyValue,
  }) {
    final primary = (primaryValue ?? '').trim();
    if (primary.isNotEmpty) {
      return primary;
    }

    final legacy = (legacyValue ?? '').trim();
    if (legacy.isNotEmpty) {
      return legacy;
    }

    return '';
  }

  static List<String> selectedStoreWriteKeys() => [
        StorageKeys.selectedStore,
        legacySelectedStoreKey,
      ];

  static List<String> selectedRegisterWriteKeys() => [
        StorageKeys.selectedRegister,
        legacySelectedRegisterKey,
      ];
}
