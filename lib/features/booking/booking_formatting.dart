String formatTimeSlot(String slot) {
  final parts = slot.split(':');
  if (parts.length != 2) return slot;
  final int h = int.tryParse(parts[0]) ?? 0;
  final int m = int.tryParse(parts[1]) ?? 0;
  final String suffix = h < 12 ? 'am' : 'pm';
  final int hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return m == 0 ? '$hr$suffix' : '$hr:${m.toString().padLeft(2, '0')}$suffix';
}

String formatBookingDateTime(String date, String timeSlot) {
  final DateTime? d = DateTime.tryParse(date);
  if (d == null) return '$date · ${formatTimeSlot(timeSlot)}';
  const List<String> days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${days[d.weekday - 1]} ${formatTimeSlot(timeSlot)}';
}

