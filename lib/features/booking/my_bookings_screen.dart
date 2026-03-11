import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/cache/local_cache.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/app_logo.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/booking/booking_card.dart';
import 'package:lubowa_sports_park/features/booking/booking_detail_screen.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key, required this.initialBookings, required this.email});

  final List<BookingItem> initialBookings;
  final String email;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MyBookingsController>(
      create: (BuildContext ctx) => MyBookingsController(
        repository: BookingRepository(apiClient: ctx.read<ApiClient>()),
        email: email,
        initialBookings: initialBookings,
      ),
      child: const _MyBookingsView(),
    );
  }
}

class MyBookingsController extends ChangeNotifier {
  MyBookingsController({
    required this.repository,
    required this.email,
    required List<BookingItem> initialBookings,
  }) : _bookings = List<BookingItem>.from(initialBookings) {
    if (_bookings.isEmpty) {
      refresh(showLoader: true);
    }
  }

  final BookingRepository repository;
  final String email;

  List<BookingItem> _bookings;
  bool _loading = false;
  String? _error;

  List<BookingItem> get bookings => _bookings;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> refresh({bool showLoader = false}) async {
    if (showLoader) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final List<BookingItem> list =
          await repository.getByEmail(email, forceRefresh: true);
      _bookings = list;
      _loading = false;
      _error = null;
      notifyListeners();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await LocalCache(prefs).setList(
        LocalCache.bookingsKey(email),
        list.map((BookingItem b) => b.toJson()).toList(),
      );
    } catch (e) {
      _loading = false;
      _error = userFriendlyApiErrorMessage(e);
      notifyListeners();
    }
  }
}

class _MyBookingsView extends StatelessWidget {
  const _MyBookingsView();

  @override
  Widget build(BuildContext context) {
    final MyBookingsController controller =
        context.watch<MyBookingsController>();
    return _MyBookingsScaffold(
      email: controller.email,
      bookings: controller.bookings,
      loading: controller.isLoading,
      error: controller.error,
      onRefresh: () => controller.refresh(showLoader: false),
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

