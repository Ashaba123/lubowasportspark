import 'package:flutter/material.dart';

/// Booking form and status. MVP: submit request; optional "My bookings" list when API exists.
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book')),
      body: const Center(child: Text('Booking — wire to custom endpoint when ready')),
    );
  }
}
