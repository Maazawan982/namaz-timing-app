import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'notification_service.dart';
import 'prayer_time_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namaz Timing App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PrayerHomePage(),
    );
  }
}

class PrayerHomePage extends StatefulWidget {
  const PrayerHomePage({super.key});

  @override
  State<PrayerHomePage> createState() => _PrayerHomePageState();
}

class _PrayerHomePageState extends State<PrayerHomePage> {
  final PrayerTimeService _prayerService = PrayerTimeService();

  List<PrayerTime> _apiPrayerTimes = [];
  final Map<String, DateTime> _manualOverrides = {};
  bool _loading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  Timer? _checkTimer;
  final Set<String> _notifiedPrayers = {};

  List<PrayerTime> get _prayerTimes {
    return _apiPrayerTimes.map((prayer) {
      final override = _manualOverrides[prayer.name];
      return PrayerTime(name: prayer.name, dateTime: override ?? prayer.dateTime);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkPrayerDue());
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final prayers = await _prayerService.fetchPrayerTimes();
      _apiPrayerTimes = prayers;
      _notifiedPrayers.clear();
      await _rescheduleNotifications();
      setState(() {
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  PrayerTime? get _nextPrayer {
    final now = DateTime.now();
    return _prayerTimes.where((item) => item.dateTime.isAfter(now)).fold<PrayerTime?>(
      null,
      (previous, current) {
        if (previous == null || current.dateTime.isBefore(previous.dateTime)) {
          return current;
        }
        return previous;
      },
    );
  }
  void _showPrayerInfo(PrayerTime prayer) {
    final isEdited = _manualOverrides.containsKey(prayer.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${prayer.name} details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time: ${DateFormat.jm().format(prayer.dateTime)}'),
              const SizedBox(height: 12),
              const Text('This time was fetched from the Aladhan API using your location.'),
              const SizedBox(height: 12),
              Text('Status: ${_prayerTimes.isNotEmpty ? 'Fetched successfully' : 'Unable to verify'}'),
              if (isEdited) ...[
                const SizedBox(height: 14),
                const Text('This prayer time has been manually overridden.', style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
              ],
            ],
          ),
          actions: [
            if (isEdited)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _manualOverrides.remove(prayer.name);
                  });
                  _rescheduleNotifications();
                },
                child: const Text('Reset'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editPrayerTime(prayer);
              },
              child: const Text('Change time'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _checkPrayerDue() {
    if (_prayerTimes.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final nowSecond = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);

    for (final prayer in _prayerTimes) {
      final prayerSecond = DateTime(
        prayer.dateTime.year,
        prayer.dateTime.month,
        prayer.dateTime.day,
        prayer.dateTime.hour,
        prayer.dateTime.minute,
        prayer.dateTime.second,
      );
      final diffSeconds = prayerSecond.difference(nowSecond).inSeconds.abs();
      if (diffSeconds <= 1 && !_notifiedPrayers.contains(prayer.name)) {
        _notifiedPrayers.add(prayer.name);
        _notifyPrayer(prayer);
      }
    }
  }

  Future<void> _notifyPrayer(PrayerTime prayer) async {
    await NotificationService.instance.playAlarmSound();
    await NotificationService.instance.showImmediateNotification(
      'It is ${prayer.name} time now',
      'It is ${prayer.name} time now. Time to pray.',
    );
    await NotificationService.instance.schedulePrayerNotification(
      _prayerTimes.indexOf(prayer) + 100,
      prayer.name,
      DateTime.now().add(const Duration(seconds: 1)),
      body: 'It is ${prayer.name} time now. Time to pray.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('It is ${prayer.name} time now. Time to pray.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _rescheduleNotifications() async {
    await NotificationService.instance.cancelAllNotifications();
    for (var i = 0; i < _prayerTimes.length; i++) {
      final prayer = _prayerTimes[i];
      await NotificationService.instance.schedulePrayerNotification(
        i + 1,
        prayer.name,
        prayer.dateTime,
      );
    }
  }

  Future<void> _editPrayerTime(PrayerTime prayer) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(prayer.dateTime),
      helpText: 'Select ${prayer.name} time',
    );

    if (pickedTime == null) {
      return;
    }

    final updatedTime = DateTime(
      prayer.dateTime.year,
      prayer.dateTime.month,
      prayer.dateTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _manualOverrides[prayer.name] = updatedTime;
    });

    await _rescheduleNotifications();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${prayer.name} has been updated to ${DateFormat.jm().format(updatedTime)}.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      appBar: AppBar(
        title: const Text('Namaz Timing App'),
        elevation: 0,
        backgroundColor: const Color(0xFF5B3F8A),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorState()
                  : _buildPrayerList(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadPrayerTimes,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        backgroundColor: const Color(0xFF5B3F8A),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
        const SizedBox(height: 16),
        Text(
          'Unable to load prayer times',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Unknown error',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loadPrayerTimes,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B3F8A),
          ),
          child: const Text('Try again'),
        ),
      ],
    );
  }

  Widget _buildPrayerList(BuildContext context) {
    final next = _nextPrayer;
    final apiStatus = _prayerTimes.isNotEmpty ? 'API status: Online' : 'API status: Offline';
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        if (next != null) ...[
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7E57C2), Color(0xFF5B3F8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next prayer', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(next.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(DateFormat.jm().format(next.dateTime), style: const TextStyle(color: Colors.white70, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Today prayer schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(apiStatus, style: TextStyle(color: _prayerTimes.isNotEmpty ? Colors.green : Colors.red, fontSize: 12)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _prayerTimes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final prayer = _prayerTimes[index];
                  final isNext = prayer == next;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(0),
                      onTap: () => _showPrayerInfo(prayer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isNext ? const Color(0xFF5B3F8A) : const Color(0xFFEDE7F6),
                              child: Icon(
                                Icons.access_time,
                                color: isNext ? Colors.white : const Color(0xFF5B3F8A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(prayer.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isNext ? const Color(0xFF5B3F8A) : Colors.black87)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _manualOverrides.containsKey(prayer.name)
                                        ? 'Edited to ${DateFormat.jm().format(prayer.dateTime)}'
                                        : 'Tap for details',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(DateFormat.jm().format(prayer.dateTime), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isNext ? const Color(0xFF5B3F8A) : Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _lastUpdated != null
              ? 'Last update: ${DateFormat.yMMMd().add_jm().format(_lastUpdated!)}'
              : 'No prayer times loaded yet.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
  }
}
