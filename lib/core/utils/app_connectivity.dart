import 'package:connectivity_plus/connectivity_plus.dart';

/// Shared instance for connectivity checks and stream.
final Connectivity _connectivity = Connectivity();

/// Returns true if the device reports a network connection (wifi, mobile, etc.).
/// Based on radio state only — does not guarantee internet reachability (e.g. captive portals).
/// Use before API calls to show a friendly "No internet" message instead of a timeout.
Future<bool> hasNetworkConnectivity() async {
  final list = await _connectivity.checkConnectivity();
  if (list.isEmpty) return false;
  return list.any((r) => r != ConnectivityResult.none);
}

/// Stream of connectivity changes. Use to show an "offline" banner or disable actions when disconnected.
Stream<List<ConnectivityResult>> get onConnectivityChanged =>
    _connectivity.onConnectivityChanged;
