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
        id: json['id'] as int,
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

  factory BookingItem.fromJson(Map<String, dynamic> json) => BookingItem(
        id: json['id'] as int,
        date: (json['date'] as String?) ?? '',
        timeSlot: (json['time_slot'] as String?) ?? '',
        contactName: (json['contact_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        createdAt: json['created_at'] as String?,
      );
}
