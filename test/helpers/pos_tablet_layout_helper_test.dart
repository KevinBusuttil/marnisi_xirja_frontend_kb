import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/pos_tablet_layout_helper.dart';

void main() {
  group('PosTabletLayoutHelper', () {
    test('detects compact height mode below breakpoint', () {
      expect(PosTabletLayoutHelper.isCompactHeight(900), isTrue);
      expect(PosTabletLayoutHelper.isCompactHeight(1060), isTrue);
      expect(PosTabletLayoutHelper.isCompactHeight(1200), isFalse);
    });

    test('uses tighter section flex in compact mode', () {
      expect(
        PosTabletLayoutHelper.itemsSectionFlex(compactHeight: true),
        13,
      );
      expect(
        PosTabletLayoutHelper.toolsSectionFlex(compactHeight: true),
        15,
      );
    });

    test('uses default section flex in normal mode', () {
      expect(
        PosTabletLayoutHelper.itemsSectionFlex(compactHeight: false),
        16,
      );
      expect(
        PosTabletLayoutHelper.toolsSectionFlex(compactHeight: false),
        14,
      );
    });

    test('returns compact heights for action bars', () {
      expect(
        PosTabletLayoutHelper.bottomActionBarHeight(compactHeight: true),
        60,
      );
      expect(
        PosTabletLayoutHelper.searchBarHeight(compactHeight: true),
        26,
      );
      expect(
        PosTabletLayoutHelper.quickActionBarHeight(compactHeight: true),
        30,
      );
    });
  });
}
