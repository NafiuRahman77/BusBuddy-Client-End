import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:busbuddy_app/components/marker_icon.dart';
import 'package:flutter/material.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../globel.dart' as globel;

class trackingMap extends StatefulWidget {
  @override
  _trackingMapUIState createState() => _trackingMapUIState();
  final dynamic extra;
  String TripID = "";
  List<dynamic> pathCoords = List.empty();
  List<dynamic> timeList = List.empty();
  List<dynamic> stationCoords = List.empty();
  List<String> stationIds = List.empty();
  List<String> stationNames = List.empty();
  List<dynamic> Function() getTimeList = () {
    return List.empty();
  };
  List<dynamic> Function() getPathCoords = () {
    return List.empty();
  };

  final Set<Marker> stationPoints = Set<Marker>();
  trackingMap({required this.extra}) {
    TripID = extra['TripID'];
    pathCoords = extra['pathCoords'];
    timeList = extra['timeList'];
    stationCoords = extra['stationCoords'];
    stationIds = extra['stationIds'];
    stationNames = extra['stationNames'];
    getTimeList = extra['sendTimeList'];
    getPathCoords = extra['sendPathCoords'];
  }
}

class _trackingMapUIState extends State<trackingMap> {
  Timer? locationUpdateTimer;
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  List<LatLng> x = List.empty();
  // a variable to store the current position
  Position? _currentPosition;

  // get current location
  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            forceAndroidLocationManager: true)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
      });
    }).catchError((e) {
      print(e);
    });
  }

  @override
  void dispose() {
    if (locationUpdateTimer != null && locationUpdateTimer!.isActive) {
      locationUpdateTimer!.cancel();
    }
    super.dispose();
  }

  MarkerGenerator markerGenerator = MarkerGenerator(jMarkerSize: 100);
  MarkerGenerator stMarkerGenerator = MarkerGenerator(jMarkerSize: 70);
  MarkerGenerator arMarkerGenerator = MarkerGenerator(jMarkerSize: 100);

  BitmapDescriptor? busIcon,
      startIcon,
      stationIcon,
      buetIcon,
      crossedStationIcon,
      arrowIcon;

  Future<void> generateIcons() async {
    print("start gen");

    startIcon = await markerGenerator.createBitmapDescriptorFromIconData(
        Icons.flag,
        Colors.white,
        Colors.transparent,
        Color.fromARGB(195, 0, 117, 185));

    busIcon = await markerGenerator.createBitmapDescriptorFromIconData(
        Icons.directions_bus_rounded,
        Colors.white,
        Colors.transparent,
        Color.fromARGB(195, 0, 117, 185));

    stationIcon = await stMarkerGenerator.createBitmapDescriptorFromIconData(
        Icons.hail, Colors.white, Colors.transparent, Color(0xff7b1b1b));

    crossedStationIcon =
        await stMarkerGenerator.createBitmapDescriptorFromIconData(
            Icons.hail,
            Color.fromARGB(255, 85, 241, 119),
            Color.fromARGB(255, 85, 241, 119),
            Color(0xff7b1b1b));

    buetIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: const Size(200, 200)),
        "lib/images/buet.png");

    arrowIcon = await arMarkerGenerator.createBitmapDescriptorFromIconData(
        Icons.play_arrow,
        Color.fromARGB(255, 170, 53, 53),
        Colors.transparent,
        Colors.transparent);

    setState(() {}); // DO NOT DELETE THIS

    print("end gen");
  }

  double pathArrowAngle(int i) {
    double dy = double.parse(widget.pathCoords[i]['latitude']) -
        double.parse(widget.pathCoords[i - 1]['latitude']);
    double dx = double.parse(widget.pathCoords[i]['longitude']) -
        double.parse(widget.pathCoords[i - 1]['longitude']);
    double rad = atan2(dy, dx);
    double deg = rad * 180.0 / pi;
    deg = 360 - deg; //ccw
    return deg;
  }

  @override
  void initState() {
    super.initState();
    //getPoints(widget.RouteID) ;
    setState(() {
      x = cnv(widget.pathCoords);
    });
    generateIcons();
    locationUpdateTimer =
        Timer.periodic(Duration(seconds: 2), (Timer timer) async {
      // await getlocationupdate(widget.TripID);
      setState(() {
        widget.pathCoords = widget.getPathCoords();
        widget.timeList = widget.getTimeList();
        x = cnv(widget.pathCoords);
      });
    });
  }

  List<LatLng> cnv(List<dynamic> pathCoords) {
    return pathCoords.map((coord) {
      return LatLng(
          double.parse(coord['latitude']), double.parse(coord['longitude']));
    }).toList();
  }

  late GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(23.7623975, 90.3646323),
            zoom: 12, // Zoom level
          ),
          // set marker on first position of path and current location
          rotateGesturesEnabled: false,
          markers: {
            Marker(
              markerId: MarkerId('first'),
              position: x[0],
              anchor: const Offset(0.5, 0.5),
              zIndex: 2.0,
              icon: (startIcon == null)
                  ? BitmapDescriptor.defaultMarker
                  : startIcon!,
            ),
            Marker(
              markerId: MarkerId('last'),
              position: x[x.length - 1],
              anchor: const Offset(0.5, 0.5),
              zIndex: 2.0,
              icon:
                  (busIcon == null) ? BitmapDescriptor.defaultMarker : busIcon!,
            ),
            // Marker(
            //   markerId: MarkerId('last'),
            //   // set marker on current location if current location is not null
            //   position: _currentPosition != null
            //       ? LatLng(
            //           _currentPosition!.latitude, _currentPosition!.longitude)
            //       : x[0],
            //   icon: BitmapDescriptor.defaultMarker,
            // )
            for (int i = 0; i < widget.timeList.length; i++)
              Marker(
                markerId: MarkerId("s$i"),
                position: LatLng(
                    double.parse(widget.stationCoords[widget.stationIds
                            .indexOf(widget.timeList[i]['station'])]['x']
                        .toString()),
                    double.parse(widget.stationCoords[widget.stationIds
                            .indexOf(widget.timeList[i]['station'])]['y']
                        .toString())),
                anchor: const Offset(0.5, 0.5),
                zIndex: 1.0,
                icon: (widget.timeList[i]['station'] != '70')
                    ? ((widget.timeList[i]['pred'] != null &&
                            widget.timeList[i]['pred'])
                        ? ((stationIcon == null)
                            ? BitmapDescriptor.defaultMarker
                            : stationIcon!)
                        : ((crossedStationIcon == null)
                            ? BitmapDescriptor.defaultMarker
                            : crossedStationIcon!))
                    : ((buetIcon == null)
                        ? BitmapDescriptor.defaultMarker
                        : buetIcon!),
                onTap: () {
                  mapController.showMarkerInfoWindow(MarkerId("s$i"));
                },
                infoWindow: InfoWindow(
                  title: widget.stationNames[
                      widget.stationIds.indexOf(widget.timeList[i]['station'])],
                  snippet: widget.timeList[i]['time'],
                ),
              ),

            for (int i = 10; i < widget.pathCoords.length; i += 10)
              Marker(
                markerId: MarkerId("arrow$i"),
                position: LatLng(
                    ((double.parse(widget.pathCoords[i]['latitude']) +
                            double.parse(
                                widget.pathCoords[i - 1]['latitude'])) /
                        2),
                    ((double.parse(widget.pathCoords[i]['longitude'])) +
                            double.parse(
                                widget.pathCoords[i - 1]['longitude'])) /
                        2),
                anchor: const Offset(0.5, 0.5),
                rotation: pathArrowAngle(i),
                zIndex: 0.0,
                icon: (arrowIcon == null)
                    ? BitmapDescriptor.defaultMarker
                    : arrowIcon!,
              ),
          },
          polylines: Set<Polyline>.of(
            [
              Polyline(
                polylineId: PolylineId('fsef'),
                //hex color code use Colors
                color: Color.fromARGB(255, 170, 53, 53),
                points: x,
                width: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
