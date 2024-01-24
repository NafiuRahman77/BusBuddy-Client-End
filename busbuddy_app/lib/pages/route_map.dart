import 'package:flutter/material.dart';
import 'dart:async';
import '../components/CustomCard.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

class RouteTimeMap extends StatefulWidget {
  @override
  _RouteTimeMap createState() => _RouteTimeMap();
  final Set<Marker> stationPoints;

  RouteTimeMap({required this.stationPoints});
}

class _RouteTimeMap extends State<RouteTimeMap> {
  // Set<Marker> markerSet = Set<Marker>();

  @override
  void initState() {
    super.initState();
    // print("hello from map");
    // globel.mapMarkerSet.forEach((element) {
    //   print(element);
    // });
    // widget.stationPoints.forEach((coord) {
    //   if (coord != null)
    //     markerSet.add(Marker(
    //       markerId: MarkerId("value"),
    //       position: LatLng(coord['x'], coord['y']),
    //     ));
    // });
  }

  // final Completer<GoogleMapController> _controller =
  //     Completer<GoogleMapController>();

  late GoogleMapController mapController;

  static const CameraPosition _kBUET = CameraPosition(
    target: LatLng(23.72759244722254, 90.39195943448034),
    zoom: 15,
  );

  static const CameraPosition _kLake = CameraPosition(
      bearing: 192.8334901395799,
      target: LatLng(37.43296265331129, -122.08832357078792),
      tilt: 59.440717697143555,
      zoom: 19.151926040649414);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(15),
        child: GoogleMap(
          mapType: MapType.hybrid,
          initialCameraPosition: CameraPosition(
            target: LatLng(
                (widget.stationPoints.elementAt(0).position.latitude +
                        widget.stationPoints
                            .elementAt(widget.stationPoints.length - 1)
                            .position
                            .latitude) /
                    2,
                (widget.stationPoints.elementAt(0).position.longitude +
                        widget.stationPoints
                            .elementAt(widget.stationPoints.length - 1)
                            .position
                            .longitude) /
                    2),
            zoom: 14,
          ),
          onMapCreated: (GoogleMapController controller) {
            mapController = controller;
          },
          markers: widget.stationPoints,
        ),
      ),
    );
  }
}
