import 'package:flutter/material.dart';

import '../../core/api/app_api_provider.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import '../../shared/app_logo.dart';
import '../../shared/football_loader.dart';
import '../../shared/page_transitions.dart';
import 'booking_repository.dart';
import 'models/booking.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Focus nodes for keyboard navigation
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _notesFocus = FocusNode();

  _BookingStep _step = _BookingStep.service;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String? _selectedService;
  bool _submitting = false;
  String? _error;

  static const _timeSlots = [
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

  static const _services = [
    'Football pitch',
    'Event Space',
    'Padel',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= BookingRepository(apiClient: AppApiProvider.apiClientOf(context));
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
      final notesText = _notesCtrl.text.trim();
      final request = BookingRequest(
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

  void _resetFlow() {
    setState(() {
      _step = _BookingStep.service;
      _error = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _selectedService = null;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'My bookings',
            onPressed: () {
              Navigator.of(context).push(
                fadeSlideRoute(builder: (_) => const _MyBookingsEntryScreen()),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 48.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  (s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s, style: TextStyle(color: colorScheme.primary)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedService = value),
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
                fadeSlideRoute(builder: (_) => const _MyBookingsEntryScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
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
                        children: [
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 32.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _selectedService ?? 'Choose date & time',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Card(
            child: InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: colorScheme.primary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _timeSlots.map((slot) {
              final selected = _selectedTimeSlot == slot;
              return FilterChip(
                selected: selected,
                label: Text(_formatTimeSlot(slot)),
                onSelected: (v) => setState(() => _selectedTimeSlot = v ? slot : null),
                selectedColor: colorScheme.primaryContainer,
                checkmarkColor: colorScheme.primary,
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final hPadding = screenWidth >= 600 ? 32.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedService != null || _selectedDate != null || _selectedTimeSlot != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedService != null)
                        Text(
                          _selectedService!,
                          style: theme.textTheme.titleMedium,
                        ),
                      if (_selectedDate != null || _selectedTimeSlot != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              decoration: const InputDecoration(labelText: 'Phone', hintText: 'Your phone'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _notesFocus.requestFocus(),
              decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
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

  Widget _buildSuccessStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('Booking submitted', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your booking request has been sent. We\'ll confirm with you shortly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _resetFlow,
              icon: const Icon(Icons.home),
              label: const Text('Book another'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  fadeSlideRoute(builder: (_) => const _MyBookingsEntryScreen()),
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

// Quick book card was used in the previous landing layout; kept here as a
// reference component if we reintroduce quick actions in the future.

class _MyBookingsEntryScreen extends StatefulWidget {
  const _MyBookingsEntryScreen();

  @override
  State<_MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<_MyBookingsEntryScreen> {
  final _emailCtrl = TextEditingController();
  BookingRepository? _repository;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= BookingRepository(apiClient: AppApiProvider.apiClientOf(context));
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
      final list = await _repository!.getByEmail(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      Navigator.of(context).pushReplacement(
        fadeSlideRoute(
          builder: (_) => _MyBookingsScreen(initialBookings: list, email: email),
        ),
      );
    } catch (e, stack) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${userFriendlyApiErrorMessage(e)}\n\nRaw error (share this if needed):\n$e\n$stack';
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onViewDetails});

  final BookingItem booking;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateTimeLabel = booking.date.isNotEmpty && booking.timeSlot.isNotEmpty
        ? _formatBookingDateTime(booking.date, booking.timeSlot)
        : booking.date.isNotEmpty
            ? booking.date
            : _formatTimeSlot(booking.timeSlot);

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
                      booking.service?.isNotEmpty == true ? booking.service! : 'Booking',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateTimeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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

class _BookingDetailScreen extends StatelessWidget {
  const _BookingDetailScreen({required this.booking});

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
                    _DetailRow(
                      label: 'Service',
                      value: booking.service?.isNotEmpty == true ? booking.service! : 'Booking',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Booked For', value: booking.date),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Booked Time', value: _formatTimeSlot(booking.timeSlot)),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Duration', value: '1 hour'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Contact', value: booking.contactName),
                    if (booking.status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Status', value: booking.status),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _MyBookingsScreen extends StatefulWidget {
  const _MyBookingsScreen({required this.initialBookings, required this.email});

  final List<BookingItem> initialBookings;
  final String email;

  @override
  State<_MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<_MyBookingsScreen> {
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
    _repository ??= BookingRepository(apiClient: AppApiProvider.apiClientOf(context));
  }

  Future<void> _refresh() async {
    if (_repository == null) return;
    try {
      final list = await _repository!.getByEmail(widget.email);
      if (!mounted) return;
      setState(() => _bookings = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: _bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 120),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings yet',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: cs.primary,
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final b = _bookings[i];
                  return _BookingCard(
                    booking: b,
                    onViewDetails: () => Navigator.of(context).push(
                      fadeSlideRoute(builder: (_) => _BookingDetailScreen(booking: b)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
