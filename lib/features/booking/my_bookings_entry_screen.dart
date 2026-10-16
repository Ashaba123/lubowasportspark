import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/booking/my_bookings_screen.dart';
import 'package:lubowa_sports_park/features/league/login_screen.dart';

/// Gate for My Bookings: bookings belong to the logged-in account.
class MyBookingsEntryScreen extends StatefulWidget {
  const MyBookingsEntryScreen({super.key});

  @override
  State<MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<MyBookingsEntryScreen> {
  BookingRepository? _repository;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository == null) {
      _repository = BookingRepository(apiClient: context.read<ApiClient>());
      _loadIfLoggedIn();
    }
  }

  Future<void> _loadIfLoggedIn() async {
    final String? token = await context.read<TokenStorage>().getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    await _load();
  }

  Future<void> _login() async {
    final bool? ok = await Navigator.of(context).push<bool>(
      fadeSlideRoute(builder: (_) => const LoginScreen()),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final List<BookingItem> list = await _repository!.getMine(forceRefresh: true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        fadeSlideRoute(builder: (_) => MyBookingsScreen(initialBookings: list)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = userFriendlyApiErrorMessage(e);
      });
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
      body: _loading
          ? const Center(child: FootballLoader(size: 32))
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text('Log in to see your bookings', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Bookings are linked to your account.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          if (_error != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _error != null ? _loadIfLoggedIn : _login,
                            icon: Icon(_error != null ? Icons.refresh : Icons.login),
                            label: Text(_error != null ? 'Try again' : 'Log in'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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
