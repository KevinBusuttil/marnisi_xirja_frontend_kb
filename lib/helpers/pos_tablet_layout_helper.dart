class PosTabletLayoutHelper {
  static const double compactHeightBreakpoint = 1200.0;

  static bool isCompactHeight(double availableHeight) {
    return availableHeight < compactHeightBreakpoint;
  }

  static int itemsSectionFlex({required bool compactHeight}) {
    return compactHeight ? 13 : 16;
  }

  static int toolsSectionFlex({required bool compactHeight}) {
    return compactHeight ? 15 : 14;
  }

  static double bottomActionBarHeight({required bool compactHeight}) {
    return compactHeight ? 60.0 : 68.0;
  }

  static double searchBarHeight({required bool compactHeight}) {
    return compactHeight ? 26.0 : 30.0;
  }

  static double quickActionBarHeight({required bool compactHeight}) {
    return compactHeight ? 30.0 : 38.0;
  }
}
