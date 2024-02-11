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
import '../components/trackingCard.dart';

class Tracking extends StatefulWidget {
  @override
  _trackingState createState() => _trackingState();
}

class _trackingState extends State<Tracking> {
  List<dynamic> trackingData = [];
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  String selectedRouteName = "";
  String selectedRouteId = "";
  String choice = "0";
  List<String> station_ids = [], station_names = [];
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
          globel.routeNames[globel.routeIDs.indexOf(globel.userDefaultRouteId)];
    }

    for (int i = 0; i < globel.routeIDs.length; i++) {
      if (globel.routeIDs[i] == globel.userDefaultRouteId) {
        selectedRouteId = globel.routeIDs[i];
        selectedRouteName = globel.routeNames[i];
      }
    }

    var r2 = await Requests.post(globel.serverIp + 'getStations');
    r2.raiseForStatus();
    List<dynamic> json2 = r2.json();
    setState(() {
      //clear the lists
      station_ids.clear();
      station_names.clear();
      station_coords.clear();
      for (int i = 0; i < json2.length; i++) {
        // List<dynamic> arr2j = json2[i]['array_to_json'];
        station_ids.add(json2[i]['id']);
        station_names.add(json2[i]['name']);
        station_coords.add(json2[i]['coords']);
        // route_st_cnt.add(arr2j.length);
      }
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

  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Align(
          alignment: Alignment.center,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Text(
                      'Track By ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(39, 158, 158, 158)
                            .withOpacity(0.9),
                      ),
                    ),
                    Radio(
                      value: "0",
                      groupValue: choice,
                      onChanged: (value) {
                        setState(() {
                          choice = value as String;
                        });
                      },
                    ),
                    Text(
                      'Route',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(39, 158, 158, 158)
                            .withOpacity(0.9),
                      ),
                    ),
                    Radio(
                      value: "1",
                      groupValue: choice,
                      onChanged: (value) {
                        setState(() {
                          choice = value as String;
                        });
                      },
                    ),
                    Text(
                      ' Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(39, 158, 158, 158)
                            .withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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
                        int idx = globel.routeNames.indexOf(selectedRouteName);
                        selectedRouteId = globel.routeIDs[idx];
                      });
                      onRouteSelect(selectedRouteId);
                    },
                    items: globel.routeNames
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 15,
              ),
              if (loadedRouteTimeData && trackingData.isNotEmpty)
                for (int i = 0; i < trackingData.length; i++)
                  TrackingCard(
                    title: trackingData[i]['bus'],
                    TripID: trackingData[i]['id'],
                    pathCoords: trackingData[i]['path'],
                    location1: station_names[station_ids
                        .indexOf(trackingData[i]["time_list"][0]['station'])],
                    time1: trackingData[i]["time_list"][0]['time'] != null
                        ? DateFormat('jm').format(DateTime.parse(
                                trackingData[i]["time_list"][0]['time'])
                            .toLocal())
                        : "--",
                    location2: station_names[station_ids.indexOf(trackingData[i]
                            ["time_list"]
                        [trackingData[i]["time_list"].length - 3]['station'])],
                    time2: trackingData[i]["time_list"]
                                    [trackingData[i]["time_list"].length - 3]
                                ['time'] !=
                            null
                        ? DateFormat('jm').format(DateTime.parse(trackingData[i]
                                        ["time_list"]
                                    [trackingData[i]["time_list"].length - 3]
                                ['time'])
                            .toLocal())
                        : "--",
                    location3: station_names[station_ids.indexOf(trackingData[i]
                            ["time_list"]
                        [trackingData[i]["time_list"].length - 1]['station'])],
                    time3: trackingData[i]["time_list"]
                                    [trackingData[i]["time_list"].length - 1]
                                ['time'] !=
                            null
                        ? DateFormat('jm').format(DateTime.parse(trackingData[i]
                                        ["time_list"]
                                    [trackingData[i]["time_list"].length - 1]
                                ['time'])
                            .toLocal())
                        : "--",
                    completeInfo: trackingData[i]["time_list"],
                    stationIds: station_ids,
                    stationNames: station_names,
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
                        SizedBox(
                          height: 20,
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            print("clicked");
                            GoRouter.of(context).push("/route_calendar");
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF781B1B),
                          ),
                          child: Text(
                            "View Schedule",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
