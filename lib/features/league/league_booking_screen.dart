import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/shared/scroll_insets.dart';
import 'package:lubowa_sports_park/shared/skeleton.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/league/models/league.dart';

/// Books a weekly pitch slot for a league in Easy!Appointments (all weeks or none).
class LeagueBookingScreen extends StatefulWidget {
  const LeagueBookingScreen({super.key, required this.league});

  final LeagueModel league;

  @override
  State<LeagueBookingScreen> createState() => _LeagueBookingScreenState();
}

class _LeagueBookingScreenState extends State<LeagueBookingScreen> with WidgetsBindingObserver {
  static const int _maxWeeks = 12;
  Timer? _pollTimer;

  BookingRepository? _repository;
  final TextEditingController _phoneCtrl = TextEditingController();

  List<BookingService>? _services;
  BookingService? _service;
  List<LeagueBookingSlot> _existing = <LeagueBookingSlot>[];
  DateTime? _date;
  List<BookingSlot> _slots = <BookingSlot>[];
  String? _time;
  int _weeks = 4;
  bool _loadingSlots = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(AppConstants.slotRefreshInterval, (_) => _loadSlots(silent: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository == null) {
      _repository = BookingRepository(apiClient: context.read<ApiClient>());
      _loadInitial();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSlots(silent: true);
  }

  Future<void> _loadInitial() async {
    try {
      final List<BookingService> services = await _repository!.getServices();
      final List<LeagueBookingSlot> existing = await _repository!.getLeagueBookings(widget.league.id);
      if (!mounted) return;
      setState(() {
        _services = services;
        _existing = existing;
        _service = services.where((BookingService s) => s.name.toLowerCase().contains('football')).firstOrNull ??
            services.firstOrNull;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _services = <BookingService>[];
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  /// [silent] refreshes keep the selection unless that time was taken meanwhile.
  Future<void> _loadSlots({bool silent = false}) async {
    if (_service == null || _date == null || _submitting) return;
    if (!silent) {
      setState(() {
        _loadingSlots = true;
        _time = null;
      });
    }
    final DateTime date = _date!;
    final int serviceId = _service!.id;
    try {
      final List<BookingSlot> slots =
          await _repository!.getSlots(serviceId: serviceId, date: formatBookingDate(date));
      if (!mounted || _date != date || _service?.id != serviceId) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
        final String? selected = _time;
        if (selected != null && !slots.any((BookingSlot s) => s.time == selected && s.isAvailable)) {
          _time = null;
          _error = '${_formatTime(selected)} was just taken. Please pick another time.';
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _slots = <BookingSlot>[];
        _loadingSlots = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  Future<void> _book() async {
    if (_service == null || _date == null || _time == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final List<LeagueBookingSlot> created = await _repository!.bookLeague(
        leagueId: widget.league.id,
        serviceId: _service!.id,
        date: formatBookingDate(_date!),
        time: _time!,
        weeks: _weeks,
        contactPhone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booked ${created.length} week${created.length == 1 ? '' : 's'}. Awaiting confirmation.')),
      );
      final List<LeagueBookingSlot> existing = await _repository!.getLeagueBookings(widget.league.id);
      if (!mounted) return;
      setState(() {
        _existing = existing;
        _submitting = false;
        _time = null;
      });
      _loadSlots();
    } on SlotTakenException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
      _loadSlots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  String _formatTime(String hhmm) {
    final List<String> parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final int h = int.tryParse(parts[0]) ?? 0;
    final int m = int.tryParse(parts[1]) ?? 0;
    final String suffix = h < 12 ? 'am' : 'pm';
    final int hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return m == 0 ? '$hr$suffix' : '$hr:${m.toString().padLeft(2, '0')}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Book pitch')),
      body: _services == null
          ? AppSkeleton(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomScrollInset(context)),
                children: <Widget>[
                  Text(widget.league.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Books the same day and time every week. If any week is taken, nothing is booked.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const InputDecorator(
                    decoration: InputDecoration(labelText: 'Service'),
                    child: Text('Service name'),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('First match date'),
                      trailing: Icon(Icons.chevron_right),
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomScrollInset(context)),
              children: <Widget>[
                Text(widget.league.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Books the same day and time every week. If any week is taken, nothing is booked.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (_existing.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text('Booked weeks', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: _existing
                          .map((LeagueBookingSlot b) => ListTile(
                                dense: true,
                                leading: Icon(Icons.event_available, color: cs.primary),
                                title: Text('${b.date} · ${_formatTime(b.time)}'),
                              ))
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: _service?.id,
                  decoration: const InputDecoration(labelText: 'Service'),
                  items: _services!
                      .map((BookingService s) => DropdownMenuItem<int>(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (int? id) {
                    setState(() => _service = _services!.firstWhere((BookingService s) => s.id == id));
                    _loadSlots();
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.calendar_today, color: cs.primary),
                    title: Text(_date == null ? 'First match date' : formatBookingDate(_date!)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: AppConstants.bookingMaxDaysAhead)),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                        _loadSlots();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingSlots)
                  AppSkeleton(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(
                        8,
                        (_) => FilterChip(label: const Text('00:00am'), onSelected: (_) {}),
                      ),
                    ),
                  )
                else if (_date != null && _slots.isEmpty)
                  Text('Closed on this day.', style: theme.textTheme.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _slots.map((BookingSlot slot) {
                      final String? tag = switch (slot.status) {
                        SlotStatus.booked => 'Booked',
                        SlotStatus.held => 'On hold',
                        _ => null,
                      };
                      return FilterChip(
                        selected: _time == slot.time && slot.isAvailable,
                        label: Text(tag == null ? _formatTime(slot.time) : '${_formatTime(slot.time)} · $tag'),
                        onSelected: slot.isAvailable
                            ? (bool v) => setState(() => _time = v ? slot.time : null)
                            : null,
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: _weeks,
                  decoration: const InputDecoration(labelText: 'Number of weeks'),
                  items: List<int>.generate(_maxWeeks, (int i) => i + 1)
                      .map((int n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (int? n) => setState(() => _weeks = n ?? 1),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact phone (optional)'),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: cs.error)),
                ],
                const SizedBox(height: 24),
                ButtonShimmer(
                  active: _submitting,
                  child: FilledButton(
                    onPressed: _time == null ? null : _book,
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: Text(_submitting ? 'Booking…' : 'Book $_weeks week${_weeks == 1 ? '' : 's'}'),
                  ),
                ),
              ],
            ),
    );
  }
}
