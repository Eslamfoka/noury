import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_status.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/settings/notification_status_panel.dart';
import 'package:nouri/features/settings/settings_screen.dart';

import '../../support/harness.dart';

void main() {
  group('NotificationStatusPanel', () {
    Future<void> pumpPanel(WidgetTester t, NotificationStatus? status) =>
        t.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: NotificationStatusPanel(
                  status: status,
                  onRequestNotifications: () {},
                  onRequestExactAlarms: () {},
                  onRequestBattery: () {},
                  onSendTest: () {},
                  onScheduleTestAdhan: () {},
                ),
              ),
            ),
          ),
        ));

    testWidgets('offers a scheduled adhan test, not just an instant one',
        (t) async {
      // The instant test proves notifications work at all; only a scheduled
      // one proves an alarm fires while the app is closed, which is the
      // property that actually matters.
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: false,
        ),
      );
      expect(find.text('جرّب الأذان بعد دقيقتين'), findsOneWidget);
      expect(find.textContaining('اقفل التطبيق'), findsOneWidget,
          reason: 'the user must be told to close the app for it to mean much');
    });

    testWidgets('shows all three checks and the test action', (t) async {
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: false,
        ),
      );
      expect(find.text('الإشعارات مفعّلة'), findsOneWidget);
      expect(find.text('التنبيهات الدقيقة مسموحة'), findsOneWidget);
      expect(find.text('مستثنى من توفير البطارية'), findsOneWidget);
      expect(find.text('إرسال إشعار تجريبي'), findsOneWidget);
    });

    testWidgets('a fully granted state offers nothing to fix', (t) async {
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: false,
        ),
      );
      expect(find.text('اسمح'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    });

    testWidgets('states the inexact-alarm limitation plainly', (t) async {
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: false,
          batteryOptimised: false,
        ),
      );
      expect(find.textContaining('ممكن يوصل متأخر'), findsOneWidget,
          reason: 'the degraded mode must be stated, not hidden');
    });

    testWidgets('offers battery guidance when optimisation is on', (t) async {
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: true,
        ),
      );
      expect(find.textContaining('بدون قيود'), findsOneWidget);
    });

    testWidgets('never uses a failure red', (t) async {
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: false,
          exactAlarmsAllowed: false,
          batteryOptimised: true,
        ),
      );
      bool isRed(Color? c) =>
          c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;
      final reds = t
          .widgetList<Icon>(find.byType(Icon))
          .where((i) => isRed(i.color));
      expect(reds, isEmpty);
    });

    testWidgets('shows a waiting state before status is read', (t) async {
      await pumpPanel(t, null);
      expect(find.text('بيتحقق…'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    late NouriDatabase db;

    Future<void> pumpSettings(WidgetTester t) async {
      await t.pumpWidget(
        testApp(db: db, child: const Scaffold(body: SettingsScreen())),
      );
      await t.pumpAndSettle();
    }

    testWidgets('renders every section', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('مواقيت الصلاة'), findsOneWidget);
        expect(find.text('فرق وقت الإقامة'), findsOneWidget);
        expect(find.text('الورد'), findsOneWidget);
      });
    });

    testWidgets('shows the Kuwait defaults', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        expect(find.text('الكويت'), findsWidgets);
        expect(find.text('شافعي'), findsOneWidget);
      });
    });

    testWidgets('states the privacy position plainly', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        // The privacy note lives at the bottom of a lazily-built ListView, so
        // it has to be scrolled into existence before it can be found.
        await t.scrollUntilVisible(
          find.textContaining('على الجهاز ده بس'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('على الجهاز ده بس'), findsOneWidget);
      });
    });

    testWidgets('raising the tasbeeh target persists it', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        expect(find.text('١٠٠'), findsWidgets);
        await t.tap(find.byIcon(Icons.add).last);
        await t.pumpAndSettle();

        expect((await db.settingsDao.get()).tasbeehTarget, 133);
      });
    });

    testWidgets('turning off a notification channel persists it', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        await t.tap(find.byType(Switch).first);
        await t.pumpAndSettle();

        expect((await db.settingsDao.get()).notifyAdhan, isFalse);
      });
    });
  });
}
