import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

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
    return Marker(
      point: place.position,
      width: 48,
      height: 48,
      child: Tooltip(
        message:
            '${destination
                ? 'Destination'
                : start
                ? 'Start'
                : 'Landmark'}: ${place.name}',
        child: Semantics(
          label:
              '${destination
                  ? 'Destination'
                  : start
                  ? 'Start'
                  : 'Landmark'}: ${place.name}',
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: destination ? colors.primary : colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary, width: 2),
            ),
            child: Icon(
              destination
                  ? Icons.flag_rounded
                  : start
                  ? Icons.trip_origin_rounded
                  : Icons.location_on_outlined,
              color: destination ? colors.onPrimary : colors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }).toList();
}
