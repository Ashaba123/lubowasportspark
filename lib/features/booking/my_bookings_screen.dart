import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/api_error_message.dart';
import '../../shared/app_logo.dart';
import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'booking_repository.dart';
import 'models/booking.dart';

// Local formatting helpers mirrored from booking_screen.dart
String formatTimeSlot(String slot) {
  final parts = slot.split(':');
  if (parts.length != 2) return slot;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final suffix = h < 12 ? 'am' : 'pm';
  final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return m == 0 ? '$hr$suffix' : '$hr:${m.toString().padLeft(2, '0')}$suffix';
}

String formatBookingDateTime(String date, String timeSlot) {
  final d = DateTime.tryParse(date);
  if (d == null) return '$date · ${formatTimeSlot(timeSlot)}';
  const days = [
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

class MyBookingsEntryScreen extends StatefulWidget {
  const MyBookingsEntryScreen({super.key});

  @override
  State<MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<MyBookingsEntryScreen> {
  final _emailCtrl = TextEditingController();
  BookingRepository? _repository;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= BookingRepository(apiClient: context.read<ApiClient>());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_repository == null) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final list = await _repository!.getByEmail(email, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      Navigator.of(context).pushReplacement(
        fadeSlideRoute(
          builder: (_) => MyBookingsScreen(initialBookings: list, email: email),
        ),
      );
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            '${userFriendlyApiErrorMessage(e)}\n\nRaw error (share this if needed):\n$e\n$stack';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 48.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Email used when booking',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _load(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _load,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? const FootballLoader(size: 22)
                          : const Text('Load my bookings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onViewDetails});

  final BookingItem booking;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateTimeLabel = booking.date.isNotEmpty && booking.timeSlot.isNotEmpty
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
            children: [
              Icon(Icons.event, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.service?.isNotEmpty == true
                          ? booking.service!
                          : 'Booking',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateTimeLabel,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
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

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final BookingItem booking;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 48.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailRow(
                      label: 'Service',
                      value: booking.service?.isNotEmpty == true
                          ? booking.service!
                          : 'Booking',
                    ),
                    const SizedBox(height: 12),
                    DetailRow(label: 'Booked For', value: booking.date),
                    const SizedBox(height: 12),
                    DetailRow(
                        label: 'Booked Time',
                        value: formatTimeSlot(booking.timeSlot)),
                    const SizedBox(height: 12),
                    const DetailRow(label: 'Duration', value: '1 hour'),
                    const SizedBox(height: 12),
                    DetailRow(label: 'Contact', value: booking.contactName),
                    if (booking.status.isNotEmpty) ...[
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.initialBookings, required this.email});

  final List<BookingItem> initialBookings;
  final String email;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late List<BookingItem> _bookings;
  BookingRepository? _repository;

  @override
  void initState() {
    super.initState();
    _bookings = widget.initialBookings;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= BookingRepository(apiClient: context.read<ApiClient>());
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repository;
    // Fallback to a single-frame view if repository isn't ready yet.
    if (repo == null) {
      return _MyBookingsScaffold(
        email: widget.email,
        initialBookings: _bookings,
      );
    }

    return StreamProvider<List<BookingItem>>.value(
      initialData: _bookings,
      value: repo.getBookingsStream(widget.email),
      child: _MyBookingsScaffold(
        email: widget.email,
        initialBookings: _bookings,
      ),
    );
  }
}

class _MyBookingsScaffold extends StatelessWidget {
  const _MyBookingsScaffold({
    required this.email,
    required this.initialBookings,
  });

  final String email;
  final List<BookingItem> initialBookings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bookings = context.watch<List<BookingItem>>();
    final isInitialEmpty = initialBookings.isEmpty && bookings.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
      ),
      body: isInitialEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 120),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your bookings...',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const FootballLoader(size: 32),
                ],
              ),
            )
          : RefreshIndicator(
              color: cs.primary,
              onRefresh: () async {
                // Underlying stream polls every few seconds; wait briefly to hint refresh.
                await Future<void>.delayed(const Duration(seconds: 1));
              },
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: bookings.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Live — updates every few seconds',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  final b = bookings[i - 1];
                  return BookingCard(
                    booking: b,
                    onViewDetails: () => Navigator.of(context).push(
                      fadeSlideRoute(
                          builder: (_) => BookingDetailScreen(booking: b)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

