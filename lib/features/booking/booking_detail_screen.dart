import 'package:flutter/material.dart';

import 'package:lubowa_sports_park/features/booking/booking_formatting.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 48.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DetailRow(
                      label: 'Service',
                      value: booking.service?.isNotEmpty == true ? booking.service! : 'Booking',
                    ),
                    const SizedBox(height: 12),
                    DetailRow(label: 'Booked For', value: booking.date),
                    const SizedBox(height: 12),
                    DetailRow(
                      label: 'Booked Time',
                      value: formatTimeSlot(booking.timeSlot),
                    ),
                    const SizedBox(height: 12),
                    const DetailRow(label: 'Duration', value: '1 hour'),
                    const SizedBox(height: 12),
                    DetailRow(label: 'Contact', value: booking.contactName),
                    if (booking.status.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      DetailRow(label: 'Status', value: booking.status),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

