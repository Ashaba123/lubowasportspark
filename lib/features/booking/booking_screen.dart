import 'package:flutter/material.dart';

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
  final _repository = BookingRepository();
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
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      await _repository.submit(request);
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
    if (email.trim().isEmpty) return [];
    setState(() => _loadingBookings = true);
    try {
      final list = await _repository.getByEmail(email.trim());
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Book at Lubowa Sports Park',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Reserve the pitch, courts, or facilities for your game or event. '
            'Choose a date and time that works for you and we\'ll get back to you to confirm.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.calendar_today, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Use the menu above to make a booking or view your existing bookings.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => setState(() => _view = _BookView.form),
                    icon: const Icon(Icons.add),
                    label: const Text('Make a booking'),
                  ),
                ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Date', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(_selectedDate == null
                  ? 'Select date'
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
            ),
            const SizedBox(height: 16),
            Text('Time slot', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedTimeSlot,
              decoration: const InputDecoration(hintText: 'Select time'),
              items: _timeSlots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedTimeSlot = v),
            ),
            const SizedBox(height: 16),
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
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
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

class _MyBookingsEntryScreen extends StatefulWidget {
  const _MyBookingsEntryScreen();

  @override
  State<_MyBookingsEntryScreen> createState() => _MyBookingsEntryScreenState();
}

class _MyBookingsEntryScreenState extends State<_MyBookingsEntryScreen> {
  final _emailCtrl = TextEditingController();
  final _repository = BookingRepository();
  List<BookingItem> _bookings = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
      final list = await _repository.getByEmail(email);
      if (!mounted) return;
      setState(() {
        _bookings = list;
        _loading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: Padding(
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
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _load,
              child: _loading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Load my bookings'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _bookings.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Loading...' : 'Enter your email and tap Load.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _bookings.length,
                      itemBuilder: (_, i) {
                        final b = _bookings[i];
                        return ListTile(
                          title: Text(b.contactName),
                          subtitle: Text('${b.date} ${b.timeSlot} · ${b.status}'),
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

class _MyBookingsScreen extends StatelessWidget {
  const _MyBookingsScreen({required this.bookings});

  final List<BookingItem> bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.isEmpty
          ? const Center(child: Text('No bookings found for this email.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookings.length,
              itemBuilder: (_, i) {
                final b = bookings[i];
                return ListTile(
                  title: Text(b.contactName),
                  subtitle: Text('${b.date} ${b.timeSlot} · ${b.status}'),
                );
              },
            ),
    );
  }
}
