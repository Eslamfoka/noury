import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone must be set before anything is scheduled, otherwise every
  // TZDateTime resolves against UTC and the adhan fires at the wrong hour.
  //
  // A failure here must not stop the app: logging, tracking, athkar and the
  // tasbeeh all work without notifications, so Nouri degrades rather than
  // refusing to start.
  final plugin = FlutterLocalNotificationsPlugin();
  final notifications = NotificationService(plugin);

  try {
    await NotificationService.initTimezone();
    await notifications.init();
  } catch (e) {
    debugPrint('Nouri: notification setup failed, continuing without it: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const NouriApp(),
    ),
  );
}
