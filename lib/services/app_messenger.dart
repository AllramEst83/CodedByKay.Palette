import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide toast/snackbar access without needing a BuildContext.
class AppMessenger {
  const AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  static void show(String message, {bool isError = false}) {
    final ScaffoldMessengerState? messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: isError ? 5 : 2),
          backgroundColor: isError ? const Color(0xFF9F1239) : null,
        ),
      );
  }

  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    show('Copied $text');
  }
}
