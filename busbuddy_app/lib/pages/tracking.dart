import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import './trackingMap.dart';
import './routeTimeCalendar.dart';

class Tracking extends StatefulWidget {
  @override
  _trackingState createState() => _trackingState();
}

class _trackingState extends State<Tracking> {
  List<dynamic> trackingData = [];
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  List<String> route_ids = [], route_names = [];
  String selectedRouteName = "";
  String selectedRouteId = "";

  @override
  void initState() {
    super.initState();
    onTrackingMount();
  }

  Future<void> onTrackingMount() async {
    context.loaderOverlay.show();
    if (globel.userType != "student") {
      globel.userDefaultRouteId = "4";
      globel.userDefaultRouteName =
          route_names[route_ids.indexOf(globel.userDefaultRouteId)];
    }

    var r1 = await Requests.post(globel.serverIp + 'getRoutes');
    r1.raiseForStatus();
    List<dynamic> json1 = r1.json();
    setState(() {
      for (int i = 0; i < json1.length; i++) {
        route_ids.add(json1[i]['id']);
        route_names.add(json1[i]['terminal_point']);
        if (json1[i]['id'] == globel.userDefaultRouteId) {
          selectedRouteId = route_ids[i];
          selectedRouteName = route_names[i];
        }
      }
    });
    route_names.forEach((element) {
      print(element);
    });

    await getPoints(globel.userDefaultRouteId);
    context.loaderOverlay.hide();
  }

  Future<void> getPoints(String RouteID) async {
    // context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getTrackingData',
        body: {
          'route': RouteID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
      trackingData = r.json();
      loadedRouteTimeData = true;
      print(trackingData);
      // for(int i=0 ; i<trackingData.length ; i++)
      // {
      //   List<dynamic> pathCoords = trackingData[i]['path'] ;
      // }
    });
    // context.loaderOverlay.hide();
  }

  Future<void> onRouteSelect(String route) async {
    context.loaderOverlay.show();
    await getPoints(route);
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0, bottom: 6.0),
                  child: Text(
                    'Select Route',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: DropdownButtonFormField<String>(
                    value: selectedRouteName,
                    onChanged: (value) {
                      setState(() {
                        // Handle dropdown selection
                        selectedRouteName = value!;
                        // print(selectedOption);
                        int idx = route_names.indexOf(selectedRouteName);
                        selectedRouteId = route_ids[idx];
                      });
                      onRouteSelect(selectedRouteId);
                    },
                    items: route_names
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (loadedRouteTimeData && trackingData.isNotEmpty)
                for (int i = 0; i < trackingData.length; i++)
                  ElevatedButton(
                    onPressed: () async {
                      print("clicked");

                      List<dynamic> pathCoords = trackingData[i]['path'];

                      GoRouter.of(context).push("/trackingmap", extra: {
                        'TripID': trackingData[i]['id'],
                        'pathCoords': pathCoords
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF781B1B),
                    ),
                    child: Text("Trip #${trackingData[i]['id']} (View on Map)",
                        style: TextStyle(color: Colors.white)),
                  ),
              if (trackingData.isEmpty)
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: EdgeInsets.only(left: 12.0, bottom: 20.0, top: 50),
                    child: Column(
                      children: [
                        Text(
                          'No running trips found on $selectedRouteName route!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.withOpacity(0.9),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            print("clicked");
                            GoRouter.of(context).push("/route_calendar");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF781B1B),
                          ),
                          child: Text("View Default Route Schedule",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
            ])));
  }
}
