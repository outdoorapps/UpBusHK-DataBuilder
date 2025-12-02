import 'dart:io';

/// Fixes Firebase_admin not terminating upon finishing
class NoKeepAliveHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.idleTimeout = Duration.zero; // Disable keep-alive
    return client;
  }
}