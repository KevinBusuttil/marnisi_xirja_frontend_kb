import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';

void main() {
  group('MarnisiPosRestrictions payment visibility', () {
    test('hides the requested payment method IDs', () {
      expect(MarnisiPosRestrictions.showPaymentMethod('1'), isFalse); // cash
      expect(MarnisiPosRestrictions.showPaymentMethod('2'), isFalse); // cheque
      expect(
          MarnisiPosRestrictions.showPaymentMethod('9'), isFalse); // gift card
      expect(MarnisiPosRestrictions.showPaymentMethod('12'), isFalse); // stripe
      expect(MarnisiPosRestrictions.showPaymentMethod('7'), isTrue); // card bov
    });
  });

  group('MarnisiPosRestrictions store/register restriction', () {
    test('locks store to the configured vineyard when present', () {
      final stores = MarnisiPosRestrictions.restrictStoreOptions([
        'store-a',
        "Marnisi M'Xlokk",
        'store-b',
      ]);

      expect(stores, [MarnisiPosRestrictions.lockedStoreId]);
    });

    test('falls back to first normalized store when locked store is absent',
        () {
      final stores = MarnisiPosRestrictions.restrictStoreOptions([
        'store-a',
        'store-a',
        '  store-b  ',
        'store-b',
      ]);

      expect(stores, ['store-a']);
    });

    test('locks register to main register when present', () {
      final registers = MarnisiPosRestrictions.restrictRegisterOptions([
        'Marnisi M\'Xlokk-MAIN',
        'Marnisi M\'Xlokk-TASTING',
      ]);

      expect(registers, [MarnisiPosRestrictions.lockedRegisterId]);
    });

    test('falls back to first normalized register when main is absent', () {
      final registers = MarnisiPosRestrictions.restrictRegisterOptions([
        'REG-01',
        'REG-01',
        '  REG-02  ',
        'REG-02',
      ]);

      expect(registers, ['REG-01']);
    });
  });
}
