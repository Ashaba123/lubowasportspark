import 'package:flutter/material.dart';

import '../../core/api/app_api_provider.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/app_connectivity.dart';
import 'booking_repository.dart';
import 'models/booking.dart';

/// Book tab: landing (title + message) by default; menu: Bookings / Make a booking.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

enum _BookView { landing, form, success }

class _BookingScreenState extends State<BookingScreen> {
  BookingRepository? _repository;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  _BookView _view = _BookView.landing;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _submitting = false;
  String? _error;
  List<BookingItem> _myBookings = [];
  bool _loadingBookings = false;

  static const _timeSlots = [
    '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00', '18:00',
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
      final request = BookingRequest(
        date: '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
        timeSlot: _selectedTimeSlot!,
        contactName: _nameCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await _repository!.submit(request);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _view = _BookView.success;
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

  Future<List<BookingItem>> _loadMyBookings(String email) async {
    if (email.trim().isEmpty || _repository == null) return [];
    setState(() => _loadingBookings = true);
    try {
      final list = await _repository!.getByEmail(email.trim());
      if (!mounted) return [];
      setState(() {
        _myBookings = list;
        _loadingBookings = false;
      });
      return _myBookings;
    } catch (_) {
      if (!mounted) return [];
      setState(() => _loadingBookings = false);
      return [];
    }
  }

  void _resetForm() {
    setState(() {
      _view = _BookView.landing;
      _error = null;
      _selectedDate = null;
      _selectedTimeSlot = null;
      _nameCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _notesCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              if (value == 'bookings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _MyBookingsEntryScreen()),
                );
              } else {
                setState(() => _view = _BookView.form);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'bookings', child: Text('Bookings')),
              const PopupMenuItem(value: 'make', child: Text('Make a booking')),
            ],
          ),
        ],
      ),
      body: _view == _BookView.landing
          ? _buildLanding()
          : _view == _BookView.success
              ? _buildSuccess()
              : _buildForm(),
    );
  }

  Widget _buildLanding() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Book at Lubowa Sports Park',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Reserve the pitch, courts, or facilities. Choose a date and time that works for you.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text('Quick book', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickBookCard(
                  icon: Icons.schedule,
                  label: 'Available now',
                  filled: true,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _selectedTimeSlot = null;
                      _view = _BookView.form;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickBookCard(
                  icon: Icons.calendar_today,
                  label: 'Schedule',
                  filled: false,
                  onTap: () => setState(() => _view = _BookView.form),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _MyBookingsEntryScreen()),
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
                          Text('My bookings', style: theme.textTheme.titleMedium),
                          Text(
                            'View or manage your reservations',
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

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('Request sent', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your booking request has been submitted. We\'ll get back to you soon.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _resetForm,
              icon: const Icon(Icons.home),
              label: const Text('Back to Book'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _emailCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      final list = await _loadMyBookings(_emailCtrl.text.trim());
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => _MyBookingsScreen(bookings: list)),
                      );
                    },
              icon: _loadingBookings
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.list),
              label: const Text('My bookings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                            Text('Date', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
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
                  label: Text(slot),
                  onSelected: (v) => setState(() => _selectedTimeSlot = v ? slot : null),
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Your name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', hintText: 'Your phone'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', hintText: 'your@email.com'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Any special requests'),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit request'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _view = _BookView.landing),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickBookCard extends StatelessWidget {
  const _QuickBookCard({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: filled ? colorScheme.primary : colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: colorScheme.primary, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: filled ? colorScheme.onPrimary : colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: filled ? colorScheme.onPrimary : colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyBookingsEntryScreen extends StatefulWidget {
  const _MyBookingsEntryScreen();

  @override
  State<_MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<_MyBookingsEntryScreen> {
  final _emailCtrl = TextEditingController();
  BookingRepository? _repository;
  List<BookingItem> _bookings = [];
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
        _bookings = list;
        _loading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Load my bookings'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _bookings.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Loading...' : 'Enter your email and tap Load.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final b = _bookings[i];
                        return _BookingCard(
                          booking: b,
                          onViewDetails: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => _BookingDetailScreen(booking: b)),
                          ),
                        );
                      },
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
    final isUpcoming = booking.status.toLowerCase() == 'pending' || booking.status.toLowerCase() == 'confirmed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lubowa Sports Park',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (isUpcoming)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Upcoming',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.status,
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${booking.date} · ${booking.timeSlot} – 1 hour',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onViewDetails,
              child: const Text('View details'),
            ),
          ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Court', value: 'Lubowa Sports Park'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Date', value: booking.date),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Time', value: booking.timeSlot),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Duration', value: '1 hour'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Contact', value: booking.contactName),
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

class _MyBookingsScreen extends StatelessWidget {
  const _MyBookingsScreen({required this.bookings});

  final List<BookingItem> bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.isEmpty
          ? Center(
              child: Text(
                'No bookings found for this email.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final b = bookings[i];
                return _BookingCard(
                  booking: b,
                  onViewDetails: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _BookingDetailScreen(booking: b)),
                  ),
                );
              },
            ),
    );
  }
}
