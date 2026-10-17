import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dio/dio.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/auth/auth_repository.dart';
import 'package:lubowa_sports_park/core/auth/token_storage.dart';
import 'package:lubowa_sports_park/core/constants/app_constants.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
import 'package:lubowa_sports_park/shared/scroll_insets.dart';
import 'package:lubowa_sports_park/features/booking/booking_device_store.dart';
import 'package:lubowa_sports_park/features/booking/booking_repository.dart';
import 'package:lubowa_sports_park/features/booking/models/booking.dart';
import 'package:lubowa_sports_park/features/booking/my_bookings_entry_screen.dart';

// Converts "16:00" → "4pm", "09:30" → "9:30am"
String _formatTimeSlot(String slot) {
  final parts = slot.split(':');
  if (parts.length != 2) return slot;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final suffix = h < 12 ? 'am' : 'pm';
  final hr = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return m == 0 ? '$hr$suffix' : '$hr:${m.toString().padLeft(2, '0')}$suffix';
}

// Converts "2026-03-26" + "16:00" → "Thursday 4pm"
String _formatBookingDateTime(String date, String timeSlot) {
  final d = DateTime.tryParse(date);
  if (d == null) return '$date · ${_formatTimeSlot(timeSlot)}';
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${days[d.weekday - 1]} ${_formatTimeSlot(timeSlot)}';
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

enum _BookingStep { service, dateTime, details, success }

class _BookingScreenState extends State<BookingScreen> with WidgetsBindingObserver {
  BookingRepository? _repository;
  BookingDeviceStore? _store;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Focus nodes for keyboard navigation
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();

  _BookingStep _step = _BookingStep.service;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  BookingService? _selectedService;
  bool _submitting = false;
  String? _error;
  List<BookingService>? _services;
  String? _servicesError;
  List<BookingSlot> _slots = <BookingSlot>[];
  bool _loadingSlots = false;
  String? _slotsError;
  bool _loggedIn = false;

  Timer? _pollTimer;
  Timer? _holdTimer;
  DateTime? _holdExpiresAt;
  bool _renewingHold = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repository == null) {
      _repository = BookingRepository(apiClient: context.read<ApiClient>());
      _loadServices();
      _loadContact();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _holdTimer?.cancel();
    _releaseHold();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_step != _BookingStep.dateTime) return;
    if (state == AppLifecycleState.resumed) {
      _loadSlots(silent: true);
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  Future<void> _loadServices() async {
    try {
      final List<BookingService> list = await _repository!.getServices();
      if (!mounted) return;
      setState(() => _services = list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _services = <BookingService>[];
        _servicesError = userFriendlyApiErrorMessage(e);
      });
    }
  }

  /// Prefills from the last booking on this device; a logged-in user's name fills an empty name field.
  Future<void> _loadContact() async {
    final TokenStorage tokenStorage = context.read<TokenStorage>();
    final ApiClient apiClient = context.read<ApiClient>();
    final BookingDeviceStore store = await BookingDeviceStore.open();
    final String? token = await tokenStorage.getToken();
    if (!mounted) return;
    setState(() {
      _store = store;
      _loggedIn = token != null && token.isNotEmpty;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = store.contactName;
      if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = store.contactPhone;
      if (_emailCtrl.text.isEmpty) _emailCtrl.text = store.contactEmail;
    });
    if (_loggedIn && _nameCtrl.text.isEmpty) {
      try {
        final user = await AuthRepository(apiClient: apiClient).getCurrentUser();
        if (mounted && _nameCtrl.text.isEmpty) setState(() => _nameCtrl.text = user.name);
      } catch (_) {
        // Name stays empty; the user types it.
      }
    }
  }

  void _goTo(_BookingStep step) {
    setState(() => _step = step);
    if (step == _BookingStep.dateTime) {
      _startPolling();
    } else {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(AppConstants.slotRefreshInterval, (_) => _loadSlots(silent: true));
  }

  void _startHoldCountdown(SlotHold hold) {
    _holdExpiresAt = DateTime.now().add(hold.expiresIn);
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_holdRemaining <= Duration.zero) {
        _renewHold();
      } else {
        setState(() {});
      }
    });
  }

  Duration get _holdRemaining {
    final DateTime? at = _holdExpiresAt;
    if (at == null) return Duration.zero;
    final Duration left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _clearHoldLocally() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdExpiresAt = null;
  }

  void _releaseHold() {
    final BookingDeviceStore? store = _store;
    final bool had = _holdExpiresAt != null;
    _clearHoldLocally();
    if (store != null && had) {
      _repository?.releaseHold(store.deviceId).catchError((_) {});
    }
  }

  String _takenMessage(String time) => '${_formatTimeSlot(time)} was just taken. Please pick another time.';

  Future<void> _selectSlot(BookingSlot slot) async {
    final BookingDeviceStore? store = _store;
    if (store == null || _selectedService == null || _selectedDate == null) return;
    setState(() {
      _selectedTimeSlot = slot.time;
      _error = null;
    });
    try {
      final SlotHold hold = await _repository!.hold(
        deviceId: store.deviceId,
        serviceId: _selectedService!.id,
        date: formatBookingDate(_selectedDate!),
        time: slot.time,
      );
      if (!mounted || _selectedTimeSlot != slot.time) return;
      setState(() => _startHoldCountdown(hold));
    } on SlotTakenException {
      if (!mounted) return;
      setState(() {
        if (_selectedTimeSlot == slot.time) _selectedTimeSlot = null;
        _error = _takenMessage(slot.time);
      });
      _loadSlots(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_selectedTimeSlot == slot.time) _selectedTimeSlot = null;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  void _deselectSlot() {
    _releaseHold();
    setState(() => _selectedTimeSlot = null);
  }

  /// Hold ran out while on the details step: extend it if the slot is still ours, else send the user back.
  Future<void> _renewHold() async {
    final BookingDeviceStore? store = _store;
    final String? time = _selectedTimeSlot;
    if (_renewingHold || store == null || time == null || _selectedService == null || _selectedDate == null) return;
    _renewingHold = true;
    try {
      final SlotHold hold = await _repository!.hold(
        deviceId: store.deviceId,
        serviceId: _selectedService!.id,
        date: formatBookingDate(_selectedDate!),
        time: time,
      );
      if (mounted) setState(() => _startHoldCountdown(hold));
    } catch (e) {
      if (!mounted) return;
      _clearHoldLocally();
      setState(() {
        _selectedTimeSlot = null;
        _error = e is SlotTakenException ? _takenMessage(time) : userFriendlyApiErrorMessage(e);
      });
      if (_step == _BookingStep.details) _goTo(_BookingStep.dateTime);
      _loadSlots(silent: true);
    } finally {
      _renewingHold = false;
    }
  }

  Future<void> _submit() async {
    if (_repository == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null || _selectedDate == null || _selectedTimeSlot == null) {
      setState(() => _error = 'Please select a service, date and time.');
      return;
    }
    if (!await hasNetworkConnectivity()) {
      setState(() => _error = userFriendlyApiErrorMessage(NoConnectivityException()));
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final String name = _nameCtrl.text.trim();
    final String phone = _phoneCtrl.text.trim();
    final String email = _loggedIn ? '' : _emailCtrl.text.trim();
    try {
      final String notesText = _notesCtrl.text.trim();
      final BookingItem created = await _repository!.submit(BookingRequest(
        serviceId: _selectedService!.id,
        date: formatBookingDate(_selectedDate!),
        time: _selectedTimeSlot!,
        contactName: name,
        contactPhone: phone,
        contactEmail: email.isEmpty ? null : email,
        notes: notesText.isEmpty ? null : notesText,
        deviceId: _store?.deviceId,
      ));
      _clearHoldLocally();
      final BookingDeviceStore? store = _store;
      if (store != null) {
        if (created.guestToken != null) await store.addGuestToken(created.guestToken!);
        await store.saveContact(name: name, phone: phone, email: _loggedIn ? store.contactEmail : email);
      }
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = null;
      });
      _goTo(_BookingStep.success);
    } on SlotTakenException {
      if (!mounted) return;
      final String time = _selectedTimeSlot!;
      _clearHoldLocally();
      setState(() {
        _submitting = false;
        _selectedTimeSlot = null;
        _error = _takenMessage(time);
      });
      _goTo(_BookingStep.dateTime);
      _loadSlots();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.response?.statusCode == 401
            ? 'Your session expired. Please log in again.'
            : userFriendlyApiErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  /// [silent] refreshes (polling, app resume) keep the current grid on screen and only report a lost slot.
  Future<void> _loadSlots({bool silent = false}) async {
    if (_repository == null || _selectedDate == null || _selectedService == null) return;
    if (!silent) {
      setState(() {
        _loadingSlots = true;
        _slotsError = null;
      });
    }
    final DateTime date = _selectedDate!;
    final int serviceId = _selectedService!.id;
    try {
      final List<BookingSlot> slots = await _repository!.getSlots(
        serviceId: serviceId,
        date: formatBookingDate(date),
        deviceId: _store?.deviceId,
      );
      if (!mounted || _selectedDate != date || _selectedService?.id != serviceId) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
        _slotsError = null;
        final String? selected = _selectedTimeSlot;
        if (selected != null && !slots.any((BookingSlot s) => s.time == selected && s.isAvailable)) {
          _selectedTimeSlot = null;
          _clearHoldLocally();
          _error = _takenMessage(selected);
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _slots = <BookingSlot>[];
        _loadingSlots = false;
        _selectedTimeSlot = null;
        _slotsError = userFriendlyApiErrorMessage(e);
      });
    }
  }

  void _resetFlow() {
    _releaseHold();
    setState(() {
      _error = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _selectedService = null;
      _slots = <BookingSlot>[];
      _notesCtrl.clear();
    });
    _goTo(_BookingStep.service);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Book'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'My bookings',
            onPressed: () {
              Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => const MyBookingsEntryScreen()),
              );
            },
          ),
        ],
      ),
      body: FadeSlideIn(
        delay: Duration.zero,
        duration: const Duration(milliseconds: 320),
        slideDistance: 16,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: () {
            switch (_step) {
              case _BookingStep.service:
                return _buildServiceStep();
              case _BookingStep.dateTime:
                return _buildDateTimeStep();
              case _BookingStep.details:
                return _buildDetailsStep();
              case _BookingStep.success:
                return _buildSuccessStep();
            }
          }(),
        ),
      ),
    );
  }

  Widget _buildServiceStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 48.0 : 24.0;

    return SingleChildScrollView(
      key: const ValueKey<_BookingStep>(_BookingStep.service),
      padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, bottomScrollInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 16),
          Text(
            'Book. Play. Enjoy.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a service.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_services == null)
            const Center(child: FootballLoader(size: 28))
          else if (_servicesError != null)
            Column(
              children: <Widget>[
                Text(_servicesError!, style: TextStyle(color: colorScheme.error), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _services = null;
                      _servicesError = null;
                    });
                    _loadServices();
                  },
                  child: const Text('Retry'),
                ),
              ],
            )
          else
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selectedService?.id,
              decoration: const InputDecoration(
                labelText: 'Service',
                hintText: 'Choose a Service',
              ),
              items: _services!
                  .map(
                    (BookingService s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.name, style: TextStyle(color: colorScheme.primary)),
                    ),
                  )
                  .toList(),
              onChanged: (int? id) {
                _releaseHold();
                setState(() {
                  _selectedService = _services!.firstWhere((BookingService s) => s.id == id);
                  _selectedTimeSlot = null;
                  _slots = <BookingSlot>[];
                });
              },
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _selectedService == null
                ? null
                : () {
                    _goTo(_BookingStep.dateTime);
                    _loadSlots();
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next'),
          ),
          const SizedBox(height: 24),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => const MyBookingsEntryScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.list_alt, color: colorScheme.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('My Bookings', style: theme.textTheme.titleMedium),
                          Text(
                            'View My Bookings',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 32.0 : 16.0;

    return SingleChildScrollView(
      key: const ValueKey<_BookingStep>(_BookingStep.dateTime),
      padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, bottomScrollInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _selectedService?.name ?? 'Choose date & time',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: InkWell(
              onTap: () async {
                final DateTime? date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: AppConstants.bookingMaxDaysAhead)),
                );
                if (date != null) {
                  _releaseHold();
                  setState(() {
                    _selectedDate = date;
                    _selectedTimeSlot = null;
                    _error = null;
                  });
                  _loadSlots();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.calendar_today, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Date',
                            style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedDate == null
                                ? 'Select date'
                                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Time slot', style: theme.textTheme.labelLarge),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_slotsError != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_slotsError!, style: TextStyle(color: colorScheme.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _loadSlots, child: const Text('Retry')),
            ),
          ] else if (_selectedDate == null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Pick a date to see times.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ] else if (_slots.isEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Closed on this day. Please pick another date.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slots.map((BookingSlot slot) {
                final bool selected = _selectedTimeSlot == slot.time;
                final String? tag = switch (slot.status) {
                  SlotStatus.booked => 'Booked',
                  SlotStatus.held => 'On hold',
                  _ => null,
                };
                return FilterChip(
                  selected: selected && slot.isAvailable,
                  label: Text(
                    tag == null ? _formatTimeSlot(slot.time) : '${_formatTimeSlot(slot.time)} · $tag',
                    style: slot.status == SlotStatus.booked
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  onSelected: slot.isAvailable
                      ? (bool v) {
                          if (v) {
                            _selectSlot(slot);
                          } else {
                            _deselectSlot();
                          }
                        }
                      : null,
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                  disabledColor: colorScheme.surfaceContainerHighest,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loadSlots,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh times'),
              ),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _releaseHold();
                    setState(() {
                      _selectedTimeSlot = null;
                      _error = null;
                    });
                    _goTo(_BookingStep.service);
                  },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedDate == null || _selectedTimeSlot == null || _holdExpiresAt == null
                      ? null
                      : () {
                          setState(() => _error = null);
                          _goTo(_BookingStep.details);
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _buildDetailsStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 32.0 : 16.0;

    return SingleChildScrollView(
      key: const ValueKey<_BookingStep>(_BookingStep.details),
      padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, bottomScrollInset(context)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_selectedService != null || _selectedDate != null || _selectedTimeSlot != null) ...<Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_selectedService != null)
                        Text(
                          _selectedService!.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      if (_selectedDate != null || _selectedTimeSlot != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          <String>[
                            if (_selectedDate != null && _selectedTimeSlot != null)
                              _formatBookingDateTime(formatBookingDate(_selectedDate!), _selectedTimeSlot!)
                            else if (_selectedDate != null)
                              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            else if (_selectedTimeSlot != null)
                              _formatTimeSlot(_selectedTimeSlot!),
                          ].join(),
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                      if (_holdExpiresAt != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Icon(Icons.timer_outlined, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Held for you · ${_formatCountdown(_holdRemaining)}',
                              style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Your name'),
              textCapitalization: TextCapitalization.words,
              validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => (_loggedIn ? _notesFocus : _emailFocus).requestFocus(),
              decoration: const InputDecoration(labelText: 'Phone', hintText: 'e.g. 0772 123456'),
              keyboardType: TextInputType.phone,
              validator: (String? v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return isValidBookingPhone(v) ? null : 'Enter a valid phone number';
              },
            ),
            const SizedBox(height: 4),
            Text(
              'We will call or WhatsApp this number to confirm.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            if (!_loggedIn) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _notesFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
                validator: (String? v) {
                  final String value = v?.trim() ?? '';
                  if (value.isEmpty) return null;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : 'Enter a valid email';
                },
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              focusNode: _notesFocus,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any special requests',
              ),
              maxLines: 2,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            _goTo(_BookingStep.dateTime);
                            _loadSlots(silent: true);
                          },
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _submitting
                        ? const FootballLoader(size: 22)
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bookingSummary() {
    final String service = _selectedService?.name ?? 'Booking';
    final String dateStr = _selectedDate == null
        ? ''
        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    final String timeStr = _selectedTimeSlot == null ? '' : _formatTimeSlot(_selectedTimeSlot!);
    return '🏟️ Lubowa Sports Park Booking\n📍 Service: $service\n📅 Date: $dateStr\n⏰ Time: $timeStr\n\nSee you at the park!';
  }

  Future<void> _shareBooking() async {
    await Share.share(_bookingSummary(), subject: 'Lubowa Sports Park Booking');
  }

  String _padTwo(int v) => v.toString().padLeft(2, '0');
  String _fmtCalDt(DateTime d) =>
      '${d.year}${_padTwo(d.month)}${_padTwo(d.day)}T${_padTwo(d.hour)}${_padTwo(d.minute)}00';

  Future<void> _addToCalendar() async {
    if (_selectedDate == null || _selectedTimeSlot == null) return;
    final String service = _selectedService?.name ?? 'Lubowa Sports Park Booking';
    final parts = _selectedTimeSlot!.split(':');
    final int hour = int.tryParse(parts[0]) ?? 9;
    final int minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final DateTime start = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      hour,
      minute,
    );
    final int minutes = _selectedService?.duration ?? 60;
    final DateTime end = start.add(Duration(minutes: minutes > 0 ? minutes : 60));

    final Uri uri = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent(service)}'
      '&dates=${_fmtCalDt(start)}/${_fmtCalDt(end)}'
      '&details=${Uri.encodeComponent('Booking at Lubowa Sports Park')}'
      '&location=${Uri.encodeComponent('Lubowa Sports Park, Kampala')}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSuccessStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return ScrollableCenter(
      key: const ValueKey<_BookingStep>(_BookingStep.success),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, color: cs.primary, size: 64),
          const SizedBox(height: 16),
          Text('Booking submitted', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Your booking request has been sent. We\'ll confirm with you shortly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_selectedService != null && _selectedDate != null && _selectedTimeSlot != null)
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(_selectedService!.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} · ${_formatTimeSlot(_selectedTimeSlot!)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareBooking,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addToCalendar,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text('Calendar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _resetFlow,
            icon: const Icon(Icons.add),
            label: const Text('Book another'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => const MyBookingsEntryScreen()),
              );
            },
            icon: const Icon(Icons.list_alt),
            label: const Text('My bookings'),
          ),
        ],
      ),
    );
  }
}
