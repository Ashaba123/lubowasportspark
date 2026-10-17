import 'package:flutter/material.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/shared/scroll_insets.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/booking/my_bookings_screen.dart';

/// Loads My Bookings (no login needed) and hands over to [MyBookingsScreen]; shows a retry on failure.
class MyBookingsEntryScreen extends StatefulWidget {
  const MyBookingsEntryScreen({super.key});

  @override
  State<MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<MyBookingsEntryScreen> {
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final List<BookingItem> list = await loadMyBookings(context);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        fadeSlideRoute(builder: (_) => MyBookingsScreen(initialBookings: list)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFriendlyApiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 48.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: _error == null
          ? const Center(child: FootballLoader(size: 32))
          : ScrollableCenter(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('Could not load your bookings', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
