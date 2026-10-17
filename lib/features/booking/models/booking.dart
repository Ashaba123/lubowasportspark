/// Bookable service from GET /lubowa-ea/v1/services (Easy!Appointments).
class BookingService {
  const BookingService({
    required this.id,
    required this.name,
    required this.duration,
    this.price,
    this.currency,
    this.description = '',
  });

  final int id;
  final String name;

  /// Minutes.
  final int duration;
  final String? price;
  final String? currency;
  final String description;

  factory BookingService.fromJson(Map<String, dynamic> json) => BookingService(
        id: BookingItem._toInt(json['id']),
        name: (json['name'] as String?) ?? '',
        duration: BookingItem._toInt(json['duration']),
        price: json['price']?.toString(),
        currency: json['currency'] as String?,
        description: (json['description'] as String?) ?? '',
      );
}

/// [held]: someone else is completing a booking for it. [mine]: held by this device.
enum SlotStatus { available, booked, held, mine, unavailable }

/// One start time on the slot grid from GET /lubowa-ea/v1/slots.
class BookingSlot {
  const BookingSlot({required this.time, required this.status});

  /// "HH:MM".
  final String time;
  final SlotStatus status;

  bool get isAvailable => status == SlotStatus.available || status == SlotStatus.mine;

  factory BookingSlot.fromJson(Map<String, dynamic> json) => BookingSlot(
        time: (json['time'] as String?) ?? '',
        status: switch (json['status']) {
          'available' => SlotStatus.available,
          'booked' => SlotStatus.booked,
          'held' => SlotStatus.held,
          'mine' => SlotStatus.mine,
          _ => SlotStatus.unavailable,
        },
      );
}

/// Booking request payload for POST /lubowa-ea/v1/bookings. Guests allowed; when logged in the
/// bridge uses the account email instead of [contactEmail].
class BookingRequest {
  const BookingRequest({
    required this.serviceId,
    required this.date,
    required this.time,
    required this.contactName,
    required this.contactPhone,
    this.contactEmail,
    this.notes,
    this.deviceId,
  });

  final int serviceId;
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final String contactName;
  final String contactPhone;
  final String? contactEmail;
  final String? notes;

  /// Lets the bridge convert this device's hold on the slot into the booking.
  final String? deviceId;

  Map<String, dynamic> toJson() => {
        'service_id': serviceId,
        'date': date,
        'time': time,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        if (contactEmail != null && contactEmail!.isNotEmpty) 'contact_email': contactEmail,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (deviceId != null) 'device_id': deviceId,
      };
}

/// Hold on a slot from POST /lubowa-ea/v1/holds.
class SlotHold {
  const SlotHold({required this.expiresIn});

  final Duration expiresIn;

  factory SlotHold.fromJson(Map<String, dynamic> json) =>
      SlotHold(expiresIn: Duration(seconds: BookingItem._toInt(json['expires_in'])));
}

/// Single booking from GET /lubowa-ea/v1/bookings.
class BookingItem {
  const BookingItem({
    required this.id,
    required this.date,
    required this.timeSlot,
    required this.contactName,
    required this.status,
    this.endTime,
    this.service,
    this.createdAt,
    this.guestToken,
  });

  final int id;
  final String date;
  final String timeSlot;
  final String? endTime;
  final String contactName;
  final String status;
  final String? service;
  final String? createdAt;

  /// Returned on create; lets this device read the booking's status without logging in.
  final String? guestToken;

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
        endTime: json['end_time'] as String?,
        contactName: (json['contact_name'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'pending',
        service: json['service'] as String?,
        createdAt: json['created_at'] as String?,
        guestToken: json['guest_token'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'time_slot': timeSlot,
        if (endTime != null) 'end_time': endTime,
        'contact_name': contactName,
        'status': status,
        if (service != null) 'service': service,
        if (createdAt != null) 'created_at': createdAt,
      };
}

/// One week of a league's pitch booking from /lubowa-ea/v1/leagues/{id}/bookings.
class LeagueBookingSlot {
  const LeagueBookingSlot({required this.appointmentId, required this.date, required this.time});

  final int appointmentId;
  final String date;
  final String time;

  factory LeagueBookingSlot.fromJson(Map<String, dynamic> json) => LeagueBookingSlot(
        appointmentId: BookingItem._toInt(json['appointment_id']),
        date: (json['date'] as String?) ?? '',
        time: (json['time'] as String?) ?? '',
      );
}

/// 409 from the bridge: the requested time (or some league weeks) are already booked.
class SlotTakenException implements Exception {
  const SlotTakenException(this.dates);

  final List<String> dates;

  @override
  String toString() => dates.isEmpty
      ? 'That time was just booked. Please pick another.'
      : 'Already booked on: ${dates.join(', ')}. Please pick another time.';
}
