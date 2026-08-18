import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper around `connectivity_plus` so the rest of the app only
/// has to ask "is Wi-Fi available right now" without depending on the
/// plugin's API shape directly (which changed from a single
/// [ConnectivityResult] to a `List<ConnectivityResult>` across major
/// versions).
class NetworkConnectivityService {
  NetworkConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// True if the device currently has a Wi-Fi connection. Other
  /// simultaneously-available transports (cellular, ethernet, VPN) don't
  /// matter here — Wi-Fi being present is all a "Wi-Fi only" check needs.
  Future<bool> isOnWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}
