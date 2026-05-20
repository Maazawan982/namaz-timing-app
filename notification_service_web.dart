import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:intl/intl.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final List<Timer> _timers = [];

  Future<void> init() async {
    if (!html.Notification.supported) {
      return;
    }

    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  }

  Future<void> schedulePrayerNotification(int id, String prayerName, DateTime scheduledTime, {String? body}) async {
    if (!html.Notification.supported) {
      return;
    }

    if (html.Notification.permission != 'granted') {
      return;
    }

    final delay = scheduledTime.difference(DateTime.now());
    if (delay.isNegative) {
      return;
    }

    final notificationBody = body ?? '$prayerName is due at ${DateFormat.jm().format(scheduledTime)}';

    _timers.add(Timer(delay, () {
      html.Notification(
        'Prayer time: $prayerName',
        body: notificationBody,
      );
    }));
  }

  Future<void> showImmediateNotification(String title, String body) async {
    if (!html.Notification.supported || html.Notification.permission != 'granted') {
      return;
    }

    html.Notification(title, body: body);
  }

  Future<void> playAlarmSound() async {
    try {
      final audio = html.AudioElement('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg')
        ..autoplay = true
        ..volume = 0.9;
      await audio.play();
    } catch (_) {
      // ignore failure to play sound in browser
    }
  }

  Future<void> cancelAllNotifications() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}
