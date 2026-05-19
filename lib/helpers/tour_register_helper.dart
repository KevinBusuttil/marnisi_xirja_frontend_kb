import 'dart:math' as math;

class TourRegisterHelper {
  const TourRegisterHelper._();

  static String normalizeStatus(String status) {
    return status.trim().toUpperCase();
  }

  static bool canStart(String status) {
    final normalized = normalizeStatus(status);
    return normalized == 'DRAFT' || normalized == 'CONFIRMED';
  }

  static bool canComplete(String status) {
    return normalizeStatus(status) == 'CHECKED_IN';
  }

  static int resolveLineQty({
    required int participantsCount,
    num? tastingQtyPerGuest,
  }) {
    final participants = participantsCount > 0 ? participantsCount : 1;
    final perGuest = (tastingQtyPerGuest != null && tastingQtyPerGuest > 0)
        ? tastingQtyPerGuest.toDouble()
        : 1.0;
    final resolved = (participants * perGuest).round();
    return math.max(1, resolved);
  }
}
