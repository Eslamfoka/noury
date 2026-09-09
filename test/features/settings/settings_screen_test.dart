import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_status.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/settings/notification_status_panel.dart';
import 'package:nouri/features/settings/settings_screen.dart';
import 'package:nouri/features/settings/settings_section_screen.dart';
import 'package:nouri/features/settings/settings_sections.dart';

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
                  onRequestDndBypass: () {},
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
      // Four rows now, not three: letting the adhan through Do Not Disturb is
      // the fourth thing the user has to grant, and it is the one that matters
      // most to a man who sleeps by day with DND on.
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: false,
          adhanBypassesDnd: true,
        ),
      );
      expect(find.text('اسمح'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    });

    testWidgets('an adhan DND can silence says so, and why it matters',
        (t) async {
      // The explanation has to name the situation rather than the API: the
      // user is not going to act on «mBypassDnd=false», but he will act on
      // "you are asleep during the day and this is the alarm that will not
      // sound".
      await pumpPanel(
        t,
        const NotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          batteryOptimised: false,
        ),
      );
      expect(find.textContaining('عدم الإزعاج'), findsWidgets);
      expect(find.textContaining('نايم بالنهار'), findsOneWidget);
      // And it is offered as something to fix, not merely reported.
      expect(find.text('اسمح'), findsOneWidget);
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

    /// Opens one section from the index.
    ///
    /// الإعدادات is a menu now: every control lives one page in. Tests that
    /// exercise a control go through here, which is also what a user does.
    Future<void> openSection(WidgetTester t, SettingsSection section) async {
      final row = find.byKey(ValueKey('settings-section-${section.name}'));
      await t.scrollUntilVisible(row, 300,
          scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      await t.tap(row);
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

    testWidgets('opens as a list of sections, not as every control at once',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);

        for (final section in SettingsSection.values) {
          expect(find.text(section.title), findsOneWidget, reason: section.name);
        }

        // A control from inside a section is not on the index.
        expect(find.text('فرق التاريخ الهجري'), findsNothing);
        expect(find.text('هدف التسبيح'), findsNothing);
        expect(find.byType(Switch), findsNothing,
            reason: 'no notification switch on the way in');
      });
    });

    // One test per section rather than a loop inside one test: each needs its
    // own database and its own navigator, and reusing a tree across iterations
    // leaves the previous section still pushed on top.
    for (final section in SettingsSection.values) {
      testWidgets('${section.title} opens, and does not open empty',
          (t) async {
        await withLargeSurface(t, () async {
          db = inMemoryDatabase(t);
          await pumpSettings(t);
          await openSection(t, section);

          expect(find.byType(SettingsSectionScreen), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(SettingsSectionScreen),
              matching: find.byType(Text),
            ),
            findsWidgets,
            reason: '${section.title} opened with nothing in it',
          );
        });
      });
    }

    testWidgets('a section holds its own controls and no others', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.iqamaOffsets);

        expect(find.text('الفجر'), findsOneWidget);
        expect(find.text('العشاء'), findsOneWidget);
        expect(find.text('هدف التسبيح'), findsNothing,
            reason: 'الورد is a different page');
      });
    });

    testWidgets('one tap on the plus moves the iqama offset once, by five',
        (t) async {
      // The reported bug, at the level the user meets it. The controller test
      // covers the concurrency; this one covers the wiring, so a later
      // refactor cannot quietly reconnect the button to an absolute setter.
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.iqamaOffsets);

        final before =
            decodeIqamaOffsets((await db.settingsDao.get()).iqamaOffsetsJson);

        final row = find.byKey(const ValueKey('iqama-dhuhr'));
        await scrollTo(t, row);
        await t.tap(find.descendant(of: row, matching: find.byIcon(Icons.add)));
        await t.pumpAndSettle();

        final after =
            decodeIqamaOffsets((await db.settingsDao.get()).iqamaOffsetsJson);
        expect(after['dhuhr'], before['dhuhr']! + 5);
        expect(after['fajr'], before['fajr'],
            reason: 'the other prayers are untouched');
      });
    });

    testWidgets('picking a shift persists it and re-plans the day', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.duty);

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
        await openSection(t, SettingsSection.duty);
        for (final k in ['morning', 'evening', 'night', 'off']) {
          expect(find.byKey(ValueKey('shift-$k')), findsOneWidget, reason: k);
        }
      });
    });

    testWidgets('shows the Kuwait defaults', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.prayerTimes);
        expect(find.text('الكويت'), findsWidgets);
        expect(find.text('شافعي'), findsOneWidget);
      });
    });

    testWidgets('carries the slogan in About, not on a splash screen',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.about);
        expect(find.textContaining('من الفجر للعشاء'), findsOneWidget);
        expect(find.textContaining('الديني والبدني والمالي'), findsOneWidget,
            reason: 'the three pillars are named where identity lives');
      });
    });

    testWidgets('states the privacy position plainly, on the way in',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        // It stays on the index: it is a statement about the whole app rather
        // than about any one setting, so it should not need a tap to find.
        await t.scrollUntilVisible(
          find.textContaining('على الجهاز ده بس'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('على الجهاز ده بس'), findsOneWidget);
      });
    });

    testWidgets('the notification panel stays on the index, not two taps deep',
        (t) async {
      // An ungranted permission means the adhan does not fire. That warning
      // belongs where it is seen on the way in.
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        expect(find.byType(NotificationStatusPanel), findsOneWidget);
      });
    });

    testWidgets('raising the tasbeeh target persists it', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.wird);

        expect(find.text('١٠٠'), findsWidgets);

        final row = find.byKey(const ValueKey('tasbeeh-target'));
        await scrollTo(t, row);
        await t.tap(find.descendant(of: row, matching: find.byIcon(Icons.add)));
        await t.pumpAndSettle();

        expect((await db.settingsDao.get()).tasbeehTarget, 133);
      });
    });

    testWidgets('turning off a notification channel persists it', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpSettings(t);
        await openSection(t, SettingsSection.notifications);

        await t.tap(find.byType(Switch).first);
        await t.pumpAndSettle();

        expect((await db.settingsDao.get()).notifyAdhan, isFalse);
      });
    });
  });
}
