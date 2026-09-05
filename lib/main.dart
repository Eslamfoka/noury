import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone must be set before any notification is scheduled, otherwise
  // every TZDateTime resolves against UTC and the adhan fires at the wrong
  // hour. Failing here must not stop the app: logging and tracking still work
  // without notifications.
  final plugin = FlutterLocalNotificationsPlugin();
  final notifications = NotificationService(plugin);

  try {
    await NotificationService.initTimezone();
    await notifications.init();
  } catch (e) {
    debugPrint('Nouri: notification setup failed, continuing without it: $e');
  }

  runApp(NouriApp(notifications: notifications));
}
