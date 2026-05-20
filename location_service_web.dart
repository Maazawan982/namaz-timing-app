// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'location_types.dart';

class LocationService {
  Future<LocationData> getCurrentLocation() async {
    final position = await html.window.navigator.geolocation.getCurrentPosition(enableHighAccuracy: true);
    final coords = position.coords;
    if (coords == null) {
      throw Exception('Unable to retrieve browser coordinates.');
    }

    return LocationData(
      latitude: coords.latitude?.toDouble() ?? 0.0,
      longitude: coords.longitude?.toDouble() ?? 0.0,
    );
  }
}
