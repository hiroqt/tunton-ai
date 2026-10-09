import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/models/landmark.dart';

List<Marker> landmarkMarkers({
  required Iterable<Landmark> landmarks,
  required String destinationId,
  String? startId,
  required ColorScheme colors,
}) {
  return landmarks.map((place) {
    final destination = place.id == destinationId;
    final start = place.id == startId;
    final isGpsLocation = place.id == 'user-current-location';
    return Marker(
      point: place.position,
      width: 48,
      height: 48,
      child: Tooltip(
        message:
            '${destination
                ? 'Destination'
                : isGpsLocation
                ? 'Your GPS Location'
                : start
                ? 'Start'
                : 'Landmark'}: ${place.name}',
        child: Semantics(
          label:
              '${destination
                  ? 'Destination'
                  : isGpsLocation
                  ? 'Your GPS Location'
                  : start
                  ? 'Start'
                  : 'Landmark'}: ${place.name}',
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: destination
                  ? colors.primary
                  : isGpsLocation
                  ? Colors.blue.shade700
                  : colors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: isGpsLocation ? Colors.blue.shade700 : colors.primary,
                width: 2,
              ),
            ),
            child: Icon(
              destination
                  ? Icons.flag_rounded
                  : isGpsLocation
                  ? Icons.my_location_rounded
                  : start
                  ? Icons.trip_origin_rounded
                  : Icons.location_on_outlined,
              color: destination || isGpsLocation
                  ? Colors.white
                  : colors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }).toList();
}

Marker userLocationMarker({
  required LatLng point,
  required ColorScheme colors,
}) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: Tooltip(
      message: 'Your live location',
      child: Semantics(
        label: 'Your live location',
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.22),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1976D2),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
