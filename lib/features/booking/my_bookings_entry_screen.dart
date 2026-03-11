import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/cache/local_cache.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/booking/my_bookings_screen.dart';

const String _lastEmailKey = 'last_bookings_email';

class MyBookingsEntryScreen extends StatefulWidget {
  const MyBookingsEntryScreen({super.key});

  @override
  State<MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<MyBookingsEntryScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  BookingRepository? _repository;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreLastEmail();
  }

  Future<void> _restoreLastEmail() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String lastEmail = prefs.getString(_lastEmailKey) ?? '';
    if (lastEmail.isNotEmpty && mounted) {
      _emailCtrl.text = lastEmail;
    }
  }

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
    final String email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LocalCache cache = LocalCache(prefs);
      final String cacheKey = LocalCache.bookingsKey(email);

      final List<Map<String, dynamic>> cached = cache.getList(cacheKey);
      final List<BookingItem> cachedBookings = cached.map(BookingItem.fromJson).toList();

      final List<BookingItem> list = await _repository!.getByEmail(email, forceRefresh: true);
      await cache.setList(cacheKey, list.map((BookingItem b) => b.toJson()).toList());
      await prefs.setString(_lastEmailKey, email);

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      Navigator.of(context).pushReplacement(
        fadeSlideRoute(
          builder: (_) => MyBookingsScreen(
            initialBookings: list.isNotEmpty ? list : cachedBookings,
            email: email,
          ),
        ),
      );
    } catch (e, stack) {
      if (!mounted) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> cached =
          LocalCache(prefs).getList(LocalCache.bookingsKey(email));
      if (cached.isNotEmpty && mounted) {
        Navigator.of(context).pushReplacement(
          fadeSlideRoute(
            builder: (_) => MyBookingsScreen(
              initialBookings: cached.map(BookingItem.fromJson).toList(),
              email: email,
            ),
          ),
        );
        return;
      }
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 48.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: Padding(
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
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loading ? null : _load,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

