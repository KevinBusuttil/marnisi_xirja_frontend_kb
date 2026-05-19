import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/tour_register_helper.dart';

void main() {
  group('TourRegisterHelper status helpers', () {
    test('normalizes and evaluates startable statuses', () {
      expect(TourRegisterHelper.normalizeStatus(' draft '), 'DRAFT');
      expect(TourRegisterHelper.canStart('DRAFT'), isTrue);
      expect(TourRegisterHelper.canStart('confirmed'), isTrue);
      expect(TourRegisterHelper.canStart('CHECKED_IN'), isFalse);
    });

    test('detects completable status', () {
      expect(TourRegisterHelper.canComplete('CHECKED_IN'), isTrue);
      expect(TourRegisterHelper.canComplete('CONFIRMED'), isFalse);
    });
  });

  group('TourRegisterHelper.resolveLineQty', () {
    test('defaults to one tasting per participant when package qty is empty',
        () {
      expect(
        TourRegisterHelper.resolveLineQty(
          participantsCount: 4,
          tastingQtyPerGuest: null,
        ),
        4,
      );
    });

    test('uses package tasting quantity when provided', () {
      expect(
        TourRegisterHelper.resolveLineQty(
          participantsCount: 3,
          tastingQtyPerGuest: 2,
        ),
        6,
      );
    });

    test('never returns less than one', () {
      expect(
        TourRegisterHelper.resolveLineQty(
          participantsCount: 0,
          tastingQtyPerGuest: 0,
        ),
        1,
      );
    });
  });
}
