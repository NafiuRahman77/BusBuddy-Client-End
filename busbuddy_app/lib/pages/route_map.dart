import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

class RouteTimeMap extends StatefulWidget {
  final Set<Marker> stationPoints;
  RouteTimeMap({required this.stationPoints});

  @override
  _RouteTimeMap createState() => _RouteTimeMap();
}

class _RouteTimeMap extends State<RouteTimeMap> {
  late GoogleMapController mapController;
  List<LatLng> stationLatLngPoints = [];

  @override
  void initState() {
    super.initState();
    convertMarkersToLatLngPoints();
  }

  void convertMarkersToLatLngPoints() {
    stationLatLngPoints = widget.stationPoints
        .map((marker) => marker.position)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    Marker startMarker = Marker(
      markerId: MarkerId('start'),
      position: stationLatLngPoints.first,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    Marker endMarker = Marker(
      markerId: MarkerId('end'),
      position: stationLatLngPoints.last,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(15),
        child: GoogleMap(
          mapType: MapType.terrain,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (stationLatLngPoints.first.latitude +
                      stationLatLngPoints.last.latitude) /
                  2,
              (stationLatLngPoints.first.longitude +
                      stationLatLngPoints.last.longitude) /
                  2,
            ),
            zoom: 14,
          ),
          onMapCreated: (GoogleMapController controller) {
            mapController = controller;
          },
          //markers: widget.stationPoints,
          // change marker of first and last station to be different
          // plz change here
          markers: {...widget.stationPoints, startMarker, endMarker},
          polylines: Set<Polyline>.of([
            Polyline(
              polylineId: PolylineId('fsef'),
              color: Colors.red,
              width: 5,
              points: stationLatLngPoints,
            ),
          ]),
        ),
      ),
    );
  }
}
