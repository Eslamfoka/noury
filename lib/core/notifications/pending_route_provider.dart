import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_route.dart';

/// The route from a notification the user tapped, waiting to be acted on.
///
/// A tap can arrive before any widget is mounted — Android launches the app
/// cold from the shade — so the route is parked here rather than pushed at a
/// navigator that may not exist yet. The shell drains it on its first frame
/// and on every later change.
///
/// Whoever handles it must call [NotificationRouteQueue.clear], or reopening
/// the app would replay the same sheet forever.
class NotificationRouteQueue extends Notifier<NotificationRoute?> {
  @override
  NotificationRoute? build() => null;

  void push(NotificationRoute? route) {
    if (route != null) state = route;
  }

  void clear() => state = null;
}

final pendingNotificationRouteProvider =
    NotifierProvider<NotificationRouteQueue, NotificationRoute?>(
  NotificationRouteQueue.new,
);
