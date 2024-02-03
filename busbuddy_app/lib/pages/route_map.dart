import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;

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
    addCustomIcon();
    globel.printWarning("station Points : ");
    print(widget.stationPoints);
    convertMarkersToLatLngPoints();
  }

  void convertMarkersToLatLngPoints() {
    stationLatLngPoints = widget.stationPoints
        .map((marker) => marker.position)
        .toList(growable: false);
  }

  BitmapDescriptor? endIcon;
  BitmapDescriptor? startIcon;

  Future<Uint8List> _getBytesFromAsset(
      String path, int width, int height) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width, targetHeight: height);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> addCustomIcon() async {
    await BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(size: Size(200, 200)),
            "lib/images/bus.png")
        .then(
      (icon) {
        setState(() {
          endIcon = icon;
        });
      },
    );

    Uint8List markerIcon =
        await _getBytesFromAsset("lib/images/Start.png", 100, 100);

    setState(() {
      startIcon = BitmapDescriptor.fromBytes(markerIcon);
    });
  }

  List<Marker> createMarkers() {
    List<Marker> markers = [];

    // Add custom marker for the first station
    markers.add(
      Marker(
        markerId: MarkerId('start'),
        position: widget.stationPoints.first.position,
        icon: startIcon!,
        onTap: () {
          mapController.showMarkerInfoWindow(
              MarkerId(widget.stationPoints.elementAt(0).markerId.value));
        },
        infoWindow: InfoWindow(
          title: widget.stationPoints.elementAt(0).infoWindow.title,
          snippet: widget.stationPoints.elementAt(0).infoWindow.snippet,
        ),
      ),
    );

    // Add default markers for stations in between
    for (int i = 1; i < widget.stationPoints.length - 1; i++) {
      markers.add(
        Marker(
          markerId: MarkerId(i.toString()),
          position: widget.stationPoints.elementAt(i).position,
          onTap: () {
            mapController.showMarkerInfoWindow(
                MarkerId(widget.stationPoints.elementAt(i).markerId.value));
          },
          infoWindow: InfoWindow(
            title: widget.stationPoints.elementAt(i).infoWindow.title,
            snippet: widget.stationPoints.elementAt(i).infoWindow.snippet,
          ),
        ),
      );
    }

    // Add custom marker for the last station
    markers.add(
      Marker(
        markerId: MarkerId('end'),
        position: widget.stationPoints.last.position,
        icon: endIcon!,
        onTap: () {
          mapController.showMarkerInfoWindow(MarkerId(widget.stationPoints
              .elementAt(widget.stationPoints.length - 1)
              .markerId
              .value));
        },
        infoWindow: InfoWindow(
          title: widget.stationPoints
              .elementAt(widget.stationPoints.length - 1)
              .infoWindow
              .title,
          snippet: widget.stationPoints
              .elementAt(widget.stationPoints.length - 1)
              .infoWindow
              .snippet,
        ),
      ),
    );

    return markers;
  }

  @override
  Widget build(BuildContext context) {
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
          markers: Set<Marker>.of(createMarkers()),
          polylines: Set<Polyline>.of([
            Polyline(
              polylineId: PolylineId('fsef'),
              color: Colors.red,
              width: 2,
              points: stationLatLngPoints,
            ),
          ]),
        ),
      ),
    );
  }
}
