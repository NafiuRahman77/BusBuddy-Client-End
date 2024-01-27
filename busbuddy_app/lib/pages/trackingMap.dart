import 'dart:async';

import 'package:flutter/material.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

class trackingMap extends StatefulWidget {
  @override
  _trackingMapUIState createState() => _trackingMapUIState();
  final dynamic extra;
  String TripID = "";
  List<dynamic> pathCoords = List.empty();

  final Set<Marker> stationPoints = Set<Marker>();
  trackingMap({required this.extra}) {
    TripID = extra['TripID'];
    pathCoords = extra['pathCoords'];
  }
}

class _trackingMapUIState extends State<trackingMap> {
  Timer? locationUpdateTimer;
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  List<LatLng> x = List.empty();
  Future<void> getlocationupdate(String TripID) async {
    var r = await Requests.post(globel.serverIp + 'getTripData',
        body: {
          'trip_id': TripID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
      var zz = r.json();
      widget.pathCoords = zz['path'] ; 
    });
  }

  @override
  void initState() {
    super.initState();
    //getPoints(widget.RouteID) ;
    x = cnv(widget.pathCoords);
    locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (Timer timer) async{  
      await getlocationupdate(widget.TripID);
      x = cnv(widget.pathCoords);
    });
  }

  List<LatLng> cnv(List<dynamic> pathCoords) {
    return pathCoords.map((coord) {
      // final ltlng = coord.substring(1,coord.length-1).split(',') ;
      // final lat = double.parse(ltlng[0]) ;
      // final lng = double.parse(ltlng[1]) ;
      return LatLng(
          double.parse(coord['latitude']), double.parse(coord['longitude']));
    }).toList();
  }

  late GoogleMapController mapController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Map with Markers'),
        ),
        body: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(23.7623975, 90.3646323), // Initial center of the map
            zoom: 12, // Zoom level
          ),
          polylines: Set<Polyline>.of([
            Polyline(
              polylineId: PolylineId('fsef'),
              color: Colors.red, // Color of the polyline
              points: x, // Pass your list of coordinates here
            ),
          ]),
        ),
      ),
    );
  }
}
