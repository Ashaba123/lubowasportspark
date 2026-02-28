import 'package:flutter/material.dart';

/// League: admin flows (login, CRUD leagues/teams/fixtures) and public stats by code.
class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('League')),
      body: const Center(child: Text('League — admin + public stats when endpoints ready')),
    );
  }
}
