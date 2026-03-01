import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true if the device has a network connection (wifi, mobile, etc.).
/// Does not guarantee actual internet reachability (e.g. captive portals).
Future<bool> hasNetworkConnectivity() async {
  final list = await Connectivity().checkConnectivity();
  return list.any((r) => r != ConnectivityResult.none);
}
