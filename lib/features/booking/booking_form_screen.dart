import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lubowa_sports_park/core/api/api_client.dart';
import 'package:lubowa_sports_park/core/utils/api_error_message.dart';
import 'package:lubowa_sports_park/core/utils/app_connectivity.dart';
import 'package:lubowa_sports_park/shared/football_loader.dart';
import 'package:lubowa_sports_park/shared/page_transitions.dart';
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

class _BookingScreenState extends State<BookingScreen> {
  BookingRepository? _repository;
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
  String? _selectedService;
  bool _submitting = false;
  String? _error;
  List<String> _bookedSlots = <String>[];
  bool _loadingSlots = false;

  static const List<String> _timeSlots = <String>[
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
  ];

  static const List<String> _services = <String>[
    'Football pitch',
    'Event Space',
    'Padel',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= BookingRepository(apiClient: context.read<ApiClient>());
  }

  @override
  void dispose() {
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

  Future<void> _submit() async {
    if (_repository == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      setState(() => _error = 'Please select a date.');
      return;
    }
    if (_selectedTimeSlot == null) {
      setState(() => _error = 'Please select a time slot.');
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
    try {
      final String notesText = _notesCtrl.text.trim();
      final BookingRequest request = BookingRequest(
        date:
            '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        timeSlot: _selectedTimeSlot!,
        contactName: _nameCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
        service: _selectedService,
        notes: notesText.isEmpty ? null : notesText,
      );
      await _repository!.submit(request);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _step = _BookingStep.success;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = userFriendlyApiErrorMessage(e);
      });
    }
  }

  Future<void> _loadBookedSlots() async {
    if (_repository == null || _selectedDate == null || _selectedService == null) return;
    setState(() => _loadingSlots = true);
    try {
      final String dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final List<String> taken = await _repository!.getBookedSlots(dateStr, _selectedService!);
      if (!mounted) return;
      setState(() {
        _bookedSlots = taken;
        _loadingSlots = false;
        if (_selectedTimeSlot != null && taken.contains(_selectedTimeSlot)) {
          _selectedTimeSlot = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bookedSlots = <String>[];
        _loadingSlots = false;
      });
    }
  }

  void _resetFlow() {
    setState(() {
      _step = _BookingStep.service;
      _error = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _selectedService = null;
      _bookedSlots = <String>[];
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _notesCtrl.clear();
    });
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
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
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
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _selectedService,
            decoration: const InputDecoration(
              labelText: 'Service',
              hintText: 'Choose a Service',
            ),
            items: _services
                .map(
                  (String s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s, style: TextStyle(color: colorScheme.primary)),
                  ),
                )
                .toList(),
            onChanged: (String? value) => setState(() => _selectedService = value),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _selectedService == null
                ? null
                : () {
                    setState(() => _step = _BookingStep.dateTime);
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
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            _selectedService ?? 'Choose date & time',
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
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _loadBookedSlots();
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
          else ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((String slot) {
                final bool selected = _selectedTimeSlot == slot;
                final bool taken = _bookedSlots.contains(slot);
                return FilterChip(
                  selected: selected && !taken,
                  label: Text(_formatTimeSlot(slot)),
                  onSelected: taken ? null : (bool v) => setState(() => _selectedTimeSlot = v ? slot : null),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                  disabledColor: colorScheme.surfaceContainerHighest,
                );
              }).toList(),
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
                  onPressed: () => setState(() => _step = _BookingStep.service),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedDate == null || _selectedTimeSlot == null
                      ? null
                      : () => setState(() => _step = _BookingStep.details),
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

  Widget _buildDetailsStep() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double hPadding = screenWidth >= 600 ? 32.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
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
                          _selectedService!,
                          style: theme.textTheme.titleMedium,
                        ),
                      if (_selectedDate != null || _selectedTimeSlot != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          <String>[
                            if (_selectedDate != null && _selectedTimeSlot != null)
                              _formatBookingDateTime(
                                '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                                _selectedTimeSlot!,
                              )
                            else if (_selectedDate != null)
                              '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            else if (_selectedTimeSlot != null)
                              _formatTimeSlot(_selectedTimeSlot!),
                          ].join(),
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              decoration: const InputDecoration(labelText: 'Phone', hintText: 'Your phone'),
              keyboardType: TextInputType.phone,
              validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _notesFocus.requestFocus(),
              decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
              keyboardType: TextInputType.emailAddress,
              validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
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
                    onPressed: () => setState(() => _step = _BookingStep.dateTime),
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
    final String service = _selectedService ?? 'Booking';
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
    final String service = _selectedService ?? 'Lubowa Sports Park Booking';
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
    final DateTime end = start.add(const Duration(hours: 1));

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
    return Center(
      child: Padding(
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
                      Text(_selectedService!, style: theme.textTheme.titleMedium),
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
      ),
    );
  }
}

