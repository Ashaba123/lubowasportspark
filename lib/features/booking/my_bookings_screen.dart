import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/shared/app_logo.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/booking/booking_card.dart';
import 'package:lubowa_sports_park/features/booking/booking_detail_screen.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.initialBookings, required this.email});

  final List<BookingItem> initialBookings;
  final String email;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _reloadToken = 0;

  Future<MyBookingsState> _loadBookings(BuildContext context) async {
    final BookingRepository repository = BookingRepository(apiClient: context.read<ApiClient>());
    try {
      final List<BookingItem> list =
          await repository.getByEmail(widget.email, forceRefresh: true);
      return MyBookingsState(bookings: list, error: null);
    } catch (e) {
      return MyBookingsState(bookings: const <BookingItem>[], error: e.toString());
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reloadToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureProvider<MyBookingsState>(
      key: ValueKey<int>(_reloadToken),
      initialData: MyBookingsState(bookings: widget.initialBookings, error: null),
      create: (BuildContext ctx) => _loadBookings(ctx),
      child: _MyBookingsView(
        email: widget.email,
        onRefresh: _refresh,
      ),
    );
  }
}

class MyBookingsState {
  MyBookingsState({required this.bookings, this.error});

  final List<BookingItem> bookings;
  final String? error;
}

class _MyBookingsView extends StatelessWidget {
  const _MyBookingsView({required this.email, required this.onRefresh});

  final String email;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final MyBookingsState state = context.watch<MyBookingsState>();
    return _MyBookingsScaffold(
      email: email,
      bookings: state.bookings,
      loading: state.bookings.isEmpty,
      error: state.error,
      onRefresh: onRefresh,
    );
  }
}

class _MyBookingsScaffold extends StatelessWidget {
  const _MyBookingsScaffold({
    required this.email,
    required this.bookings,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final String email;
  final List<BookingItem> bookings;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isEmptyAndLoading = bookings.isEmpty && loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
      ),
      body: isEmptyAndLoading
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
              onRefresh: onRefresh,
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
                          'Pull down to refresh bookings',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  final b = bookings[i - 1];
                  return BookingCard(
                    key: ValueKey(b.id),
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

