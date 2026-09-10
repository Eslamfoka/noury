import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_gateway.dart';
import 'adhan_sounds.dart';
import 'armed_window.dart';
import 'dnd_bypass.dart';
import 'notification_channels.dart';
import 'notification_slot.dart';
import 'notification_status.dart';

/// Owns the plugin: initialisation, channels, permissions, and reading the
/// honest status of whether notifications will actually arrive.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Completes once the timezone database is loaded.
  ///
  /// Timezone init is deferred off the startup path (it cost 1.5s of blank
  /// screen), but nothing may schedule before it finishes or every TZDateTime
  /// would resolve against UTC. Scheduling paths await this rather than
  /// assuming it is done.
  Future<void>? _warmUp;

  // ignore: use_setters_to_change_properties
  void attachWarmUp(Future<void> warmUp) => _warmUp = warmUp;

  Future<void> _ensureReady() async {
    final w = _warmUp;
    if (w != null) await w;
  }

  /// Which variant of the adhan channels is the live one.
  ///
  /// Settled at [init] from whether the user has granted notification-policy
  /// access, and read by anything that posts an adhan *now* — the test
  /// notification and الأصوات. Posting to the other variant would be posting
  /// to a channel that was just deleted, which Android answers by silently
  /// recreating it at default importance with no sound: the preview would play
  /// nothing and look like the recording was broken.
  bool _adhanBypassing = false;

  /// The adhan channel for [prayer] as it exists on this device right now.
  String liveAdhanChannel(String prayer) =>
      adhanChannelFor(prayer, bypassing: _adhanBypassing);

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Must run before anything is scheduled: without the local timezone set,
  /// every TZDateTime would be computed against UTC and the adhan would fire
  /// at the wrong hour.
  static Future<void> initTimezone() async {
    tzdata.initializeTimeZones();
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name.identifier));
  }

  Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      // **The half that was missing.** An action declared with
      // `showsUserInterface: false` is delivered to a *background isolate*,
      // not to the running app — and with no handler registered here, the tap
      // goes nowhere at all. That is exactly what happened to the «صليت»
      // action, which was silently dead until it was changed to open the app.
      //
      // «فكّرني بعد ٥ دقايق» must not open the app — being dragged into a
      // screen is the opposite of putting something off — so this time the
      // handler is registered.
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    // One read, then only the writes that would actually change something.
    //
    // This runs **before the first frame** — `main` awaits it — so it is the
    // one part of notification setup the user waits behind. It used to issue
    // 33 deletes and ~30 creates unconditionally, every launch, and from the
    // second launch onward every one of them was a no-op. `channelWorkFor`
    // says which are not; see the note there for why name and description are
    // the only fields worth comparing.
    //
    // Deletes go first, so the settings screen never shows two «الأذان» rows
    // with only one of them live.
    final work = channelWorkFor(
      existing: await _android?.getNotificationChannels() ??
          const <AndroidNotificationChannel>[],
    );

    for (final id in work.toDelete) {
      await _android?.deleteNotificationChannel(channelId: id);
    }
    for (final channel in work.toCreate) {
      await _android?.createNotificationChannel(channel);
    }

    await _createAdhanChannels();
  }

  /// Creates the five adhan channels through the native plugin.
  ///
  /// **Why not `flutter_local_notifications` like everything else.** Only the
  /// adhan needs to bypass Do Not Disturb, and the plugin has no way to ask
  /// for it. The user sleeps by day after a night shift with DND on, so the
  /// adhan being the one thing DND silences is not an edge case for him — it
  /// is most of the week.
  ///
  /// Bypassing means a second channel id, because Android fixes the bypass at
  /// creation. Both variants are created through the same call and the one
  /// that is not current is deleted, so the user never sees ten «الأذان» rows.
  Future<void> _createAdhanChannels() async {
    const dnd = DndBypass();
    final bypassing = await dnd.hasPolicyAccess();
    _adhanBypassing = bypassing;

    await dnd.ensureAdhanChannels([
      for (final prayer in adhanPrayers)
        AdhanChannelSpec(
          id: adhanChannelFor(prayer, bypassing: bypassing),
          name: 'الأذان — ${adhanArabicNames[prayer]}',
          description: 'إشعار دخول وقت ${adhanArabicNames[prayer]}',
          sound: adhanSoundFor(prayer),
          bypass: bypassing,
        ),
    ]);

    // The variant that is no longer current. Left behind it would sit in the
    // user's notification settings looking live, and nothing would ever fire
    // on it.
    await dnd.deleteChannels(
      bypassing ? adhanChannelIds : adhanBypassChannelIds,
    );
  }

  /// Cancels one pending notification by id.
  ///
  /// Used to silence the follow-ups for a prayer once it has been logged.
  Future<void> cancel(int id) async {
    await _ensureReady();
    await _plugin.cancel(id: id);
  }

  /// The one thing a *scheduler* needs to know, and nothing else.
  ///
  /// [readStatus] answers four questions across four platform round-trips, and
  /// three of them exist for the settings panel. Only this one changes what
  /// gets scheduled, so only this one belongs on the startup path — where the
  /// full read was measured at about 5.5s on a cold-booted emulator, delaying
  /// the window arm behind it for no purpose. The expensive part is almost
  /// certainly `permission_handler` initialising on a cold start, and the
  /// settings panel is a fine place to pay for that: it opens with a spinner,
  /// while startup does not.
  Future<NotificationMode> readMode() async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    return exact ? NotificationMode.exact : NotificationMode.inexact;
  }

  /// What the device is *actually* holding, read back rather than assumed.
  ///
  /// Every other row in حالة التنبيهات answers "is Nouri allowed to do this".
  /// This one answers "did it actually happen", which turned out to be a
  /// different question: on 10 September 2026 every permission was granted and
  /// four days of the user's prayer alarms were simply not there.
  ///
  /// Empty on any failure. A panel that cannot read the window should say it
  /// holds nothing rather than invent a reassuring number.
  ///
  /// **Waits for the launch arm to finish first**, which is not a detail.
  /// Measured on the emulator: opening الإعدادات while the window was still
  /// being written reported «١٣٤ — لحد ١٩ سبتمبر» for a device that ended the
  /// same second at 232 through the 23rd. Read a moment earlier still and the
  /// count is low enough to be reported as *missing days* — a false alarm
  /// about the one thing this row exists to be trusted about, raised by the
  /// app against itself while it was busy doing the right thing.
  ///
  /// Once the warm-up has completed this returns immediately, so the wait is
  /// only ever paid by someone who opens the settings screen within a few
  /// seconds of launching.
  Future<ArmedWindow> readArmedWindow() async {
    await _ensureReady();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return armedWindowFrom(pending.map((r) => r.id));
    } catch (_) {
      return const ArmedWindow(count: 0, days: {});
    }
  }

  /// Reads the live device state. Nothing here is cached — the settings panel
  /// must show what is true right now, not what was true at launch.
  ///
  /// The four reads are independent, so they are asked together rather than
  /// one after another: the screen waits for the slowest, not for the sum.
  Future<NotificationStatus> readStatus() async {
    // Read off the live channel, not from the request. `setBypassDnd(true)` is
    // accepted and silently ignored without policy access, so the only honest
    // answer comes from asking the system what the channel actually is.
    final adhanIds = {...adhanChannelIds, ...adhanBypassChannelIds};

    final (enabled, exact, batteryExempt, report) = await (
      _android?.areNotificationsEnabled() ?? Future.value(false),
      _android?.canScheduleExactNotifications() ?? Future.value(false),
      Permission.ignoreBatteryOptimizations.isGranted,
      const DndBypass().channelReport(ids: adhanIds.toList()),
    ).wait;

    final adhanRows = report.where((c) => adhanIds.contains(c.id));
    final bypassing =
        adhanRows.isNotEmpty && adhanRows.every((c) => c.bypassDnd);

    return NotificationStatus(
      notificationsEnabled: enabled ?? false,
      exactAlarmsAllowed: exact ?? false,
      batteryOptimised: !batteryExempt,
      adhanBypassesDnd: bypassing,
    );
  }

  Future<void> requestNotificationPermission() async {
    await _android?.requestNotificationsPermission();
  }

  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  Future<void> requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  /// Sends the user to the system screen that lets the adhan through DND.
  ///
  /// Returns false when that screen could not be opened — a few manufacturers
  /// remove it — so the caller can say so rather than leaving the user waiting
  /// for something that will never appear.
  ///
  /// Granting it is not the end of the job. The bypass is fixed when a channel
  /// is created, so the channels have to be built again on the other variant
  /// and the window re-armed onto them; the caller does that on return.
  Future<bool> openDndSettings() => const DndBypass().openPolicySettings();

  /// Rebuilds the adhan channels against the current policy-access state.
  ///
  /// Called when the user comes back from the system screen. Cheap, and safe
  /// to call when nothing changed.
  Future<void> refreshAdhanChannels() => _createAdhanChannels();

  /// Fires immediately, so the whole chain can be verified on the real device
  /// in seconds rather than by waiting for a prayer.
  ///
  /// Deliberately sent on the **adhan** channel, not the general one. The
  /// point of a test is to hear what the adhan will actually sound like — its
  /// bundled chime, at alarm volume, with the adhan channel's importance. A
  /// test on the general channel only proves that notifications work at all,
  /// which is the least interesting thing about them, and it was misleading in
  /// practice: it played the plain system beep and looked like the chime had
  /// failed.
  Future<void> sendTestNotification() async {
    await _ensureReady();
    final gateway = LocalNotificationGateway(_plugin, mode: await readMode());
    await gateway.showNow(
      title: 'نوري — تجربة الأذان',
      body: 'كده هيبقى شكل تنبيه الأذان وصوته.',
      channelId: liveAdhanChannel('dhuhr'),
    );
  }

  /// Plays one channel's sound on demand, for الأصوات.
  ///
  /// **Why a notification rather than an audio player.** Android reads a
  /// notification's sound off its channel, so the only way to hear what an
  /// alarm will *actually* sound like — the right file, at alarm volume,
  /// through the channel the user may have retuned in system settings — is to
  /// post one on that channel. Playing the raw asset with an audio plugin
  /// would add a dependency and still answer a different question.
  ///
  /// Every preview reuses `testNotificationId`, so auditioning nineteen tones
  /// leaves one notification in the shade rather than nineteen.
  Future<void> previewSound(
    String channelId, {
    required String title,
    required String body,
  }) async {
    await _ensureReady();
    final gateway = LocalNotificationGateway(_plugin, mode: await readMode());
    await gateway.showNow(
      title: title,
      body: body,
      // Normalised here rather than at each call site. An adhan has two
      // possible channels and only one of them exists at a time; posting to
      // the other makes Android quietly recreate it at default importance with
      // no sound, so the preview would play nothing and the user would
      // conclude the recording was broken rather than that Nouri asked for the
      // wrong channel.
      channelId: _liveVariantOf(channelId),
      preview: true,
    );
  }

  /// Maps an adhan channel id onto whichever variant currently exists.
  /// Anything else is returned untouched.
  String _liveVariantOf(String channelId) {
    if (!isAdhanChannel(channelId)) return channelId;
    final base = adhanBaseChannel(channelId);
    final prayer = adhanPrayers.firstWhere(
      (p) => adhanChannelFor(p) == base,
      orElse: () => '',
    );
    return prayer.isEmpty ? channelId : liveAdhanChannel(prayer);
  }

  /// Schedules a real adhan-style alarm a couple of minutes out.
  ///
  /// This is the only way to honestly test the thing that matters: not
  /// "can the app show a notification while it is open", but "does an alarm
  /// the app scheduled earlier fire while the app is closed". It goes through
  /// the same gateway, the same channel and the same AlarmManager path as a
  /// real adhan — only the time and the wording differ.
  ///
  /// It deliberately does **not** re-arm the window afterwards, so a test can
  /// never disturb the real schedule.
  Future<DateTime> scheduleTestAdhan({
    Duration delay = const Duration(minutes: 2),
  }) async {
    await _ensureReady();
    final gateway = LocalNotificationGateway(_plugin, mode: await readMode());
    final when = DateTime.now().add(delay);

    await gateway.schedule(ScheduledNotification(
      id: testAdhanNotificationId,
      slot: NotificationSlot.adhanFajr, // only used for logging
      when: when,
      title: 'نوري — تجربة الأذان',
      body: 'لو سمعت ده والتطبيق مقفول، يبقى الأذان هيوصلك في وقته.',
      channelId: liveAdhanChannel('dhuhr'),
    ));

    return when;
  }
}
