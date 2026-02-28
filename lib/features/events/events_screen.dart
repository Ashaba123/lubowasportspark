import 'package:flutter/material.dart';

/// Events list and detail — fetches from wp/v2/posts. MVP: list + detail + pull-to-refresh.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: const Center(child: Text('Events — wire to wp/v2/posts')),
    );
  }
}
