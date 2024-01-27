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
  String RouteID ; 

  final Set<Marker> stationPoints = Set<Marker>();
  trackingMap({required this.RouteID});
}
class _trackingMapUIState extends State<trackingMap> {

  List<dynamic> trackingData = [];
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  List<LatLng>x = List.empty();

  @override
  void initState() {
    super.initState();
    getPoints(widget.RouteID) ; 
  }
  Future<void> getPoints(String RouteID) async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getTrackingData',
        body: {
          'route': RouteID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
    trackingData = r.json();
    loadedRouteTimeData = true;
    //print(trackingData) ; 
    List<dynamic> pathCoords = trackingData[5]['path_'] ; 
    x = cnv(pathCoords) ; 
    print(x) ; 

          // routeCoords.clear();

    });
    context.loaderOverlay.hide();
  }
  List<LatLng> cnv(List<dynamic>pathCoords){
    return pathCoords.map((coord){
        final ltlng = coord.substring(1,coord.length-1).split(',') ; 
        final lat = double.parse(ltlng[0]) ; 
        final lng = double.parse(ltlng[1]) ; 
        return LatLng(lat, lng) ; 
    }).toList() ; 
  }

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
              polylineId: PolylineId('busPath'),
              color: Colors.blue, // Color of the polyline
              points: x, // Pass your list of coordinates here
            ),
          ]),
          
        ),
      ),
    );
  }
}
