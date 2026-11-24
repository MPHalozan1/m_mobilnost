// Pure Google encoded-polyline decoder (precision 1e5) with no Flutter deps.

import 'package:latlong2/latlong.dart';

/// Decodes a Google Maps encoded polyline string (precision 1e5) into
/// geographic [LatLng] coordinates.
///
/// Malformed or truncated input is decoded as far as possible; an empty
/// string yields an empty list.
// Note: negative deltas use -(x) - 1 instead of ~x, because on the web `~`
// yields an unsigned 32-bit value and would corrupt every coordinate.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final dlat = (result & 1) != 0 ? (-(result >> 1) - 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      if (index >= encoded.length) break;
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20 && index < encoded.length);
    final dlng = (result & 1) != 0 ? (-(result >> 1) - 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
