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

    /// Brings [target] fully into view.
    ///
    /// scrollUntilVisible stops as soon as the target is *built*, and a lazy
    /// ListView builds 250px (the default cacheExtent) past the viewport — so
    /// on its own it can leave the target just off screen, where a tap misses
    /// it and silently does nothing. ensureVisible is what actually brings it
    /// into view. Same helper, same reason, as in home_screen_test.
    Future<void> scrollTo(WidgetTester t, Finder target) async {
      await t.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(target);
      await t.pumpAndSettle();
    }

    testWidgets('renders every section', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('الدوام'), findsOneWidget);
        expect(find.text('البدن والمشي'), findsOneWidget);

        // Below the fold now that الدوام sits above them.
        await scrollTo(t, find.text('مواقيت الصلاة'));
        expect(find.text('مواقيت الصلاة'), findsOneWidget);
        await scrollTo(t, find.text('فرق وقت الإقامة'));
        expect(find.text('فرق وقت الإقامة'), findsOneWidget);

        // Below the fold now that البدن والمشي sits above it.
        await scrollTo(t, find.text('الورد'));
        expect(find.text('الورد'), findsOneWidget);
      });
    });

    testWidgets('picking a shift persists it and re-plans the day', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        expect((await db.settingsDao.get()).shiftType, 'morning');

        await scrollTo(t, find.byKey(const ValueKey('shift-night')));
        await t.tap(find.byKey(const ValueKey('shift-night')));
        await t.pumpAndSettle();

        expect((await db.settingsDao.get()).shiftType, 'night');
      });
    });

    testWidgets('all four shifts are offered', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        for (final k in ['morning', 'evening', 'night', 'off']) {
          expect(find.byKey(ValueKey('shift-$k')), findsOneWidget, reason: k);
        }
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

    testWidgets('carries the slogan in About, not on a splash screen',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await t.scrollUntilVisible(
          find.text('عن نوري'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('من الفجر للعشاء'), findsOneWidget);
        expect(find.textContaining('الديني والبدني والمالي'), findsOneWidget,
            reason: 'the three pillars are named where identity lives');
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

        await scrollTo(t, find.text('الورد'));
        expect(find.text('١٠٠'), findsWidgets);

        await scrollTo(t, find.byIcon(Icons.add).last);
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
