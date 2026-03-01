/// Booking request payload for POST /lubowa/v1/bookings.
class BookingRequest {
  const BookingRequest({
    required this.date,
    required this.timeSlot,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    this.notes,
  });

  final String date; // YYYY-MM-DD
  final String timeSlot;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'date': date,
        'time_slot': timeSlot,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

/// Response from POST /lubowa/v1/bookings (201).
class BookingSubmitResponse {
  const BookingSubmitResponse({required this.id, required this.status});

  final int id;
  final String status;

  factory BookingSubmitResponse.fromJson(Map<String, dynamic> json) =>
      BookingSubmitResponse(
        id: BookingItem._toInt(json['id']),
        status: (json['status'] as String?) ?? 'pending',
      );
}

/// Single booking from GET /lubowa/v1/bookings?contact_email=...
class BookingItem {
  const BookingItem({
    required this.id,
    required this.date,
    required this.timeSlot,
    required this.contactName,
    required this.status,
    this.createdAt,
  });

  final int id;
  final String date;
  final String timeSlot;
  final String contactName;
  final String status;
  final String? createdAt;

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
        id: _toInt(json['id']),
        date: (json['date'] as String?) ?? '',
        timeSlot: (json['time_slot'] as String?) ?? '',
        contactName: (json['contact_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        createdAt: json['created_at'] as String?,
      );
}
