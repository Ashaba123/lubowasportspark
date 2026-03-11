import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/features/booking/booking_formatting.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onViewDetails});

  final BookingItem booking;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String dateTimeLabel = booking.date.isNotEmpty && booking.timeSlot.isNotEmpty
        ? formatBookingDateTime(booking.date, booking.timeSlot)
        : booking.date.isNotEmpty
            ? booking.date
            : formatTimeSlot(booking.timeSlot);

    return Card(
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Icons.event, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      booking.service?.isNotEmpty == true ? booking.service! : 'Booking',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateTimeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

