class PortalHeaderTimeHelper {
  static String formatElapsed(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static String formatDateTimeWithoutSeconds(DateTime time) {
    final day = time.day.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final year = time.year.toString();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
