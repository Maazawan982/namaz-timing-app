import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'location_service.dart';

class PrayerTime {
  final String name;
  final DateTime dateTime;

  const PrayerTime({required this.name, required this.dateTime});
}

class PrayerTimeService {
  Future<List<PrayerTime>> fetchPrayerTimes() async {
    final position = await LocationService().getCurrentLocation();
    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MM-yyyy').format(now);
    final uri = Uri.parse(
      'https://api.aladhan.com/v1/timings/$formattedDate?latitude=${position.latitude}&longitude=${position.longitude}&method=2&school=0',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load prayer times: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 200 || body['data'] == null) {
      throw Exception('Prayer time API returned an unexpected response.');
    }

    final timings = Map<String, dynamic>.from(body['data']['timings'] as Map);
    final prayNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return prayNames.map((name) {
      final value = timings[name] as String;
      return PrayerTime(name: name, dateTime: _parsePrayerTime(value, now));
    }).toList();
  }

  DateTime _parsePrayerTime(String time, DateTime referenceDate) {
    final cleaned = time.split(' ').first.trim();
    final parsed = DateFormat('HH:mm').parse(cleaned);
    return DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      parsed.hour,
      parsed.minute,
    );
  }
}
