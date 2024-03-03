import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;
import './circlewidget.dart';
import '../components/driverHelperInfo.dart';

class TrackingCard extends StatefulWidget {
  final String title;
  String TripID = "";
  List<dynamic> pathCoords = List.empty();
  final String location1;
  final String time1;
  final String location2;
  final String time2;
  final String location3;
  final String time3;
  List<dynamic> completeInfo;
  final List<String> stationIds;
  final List<String> stationNames;
  final String driverName;
  final String driverPhone;
  final String helperName;
  final String helperPhone;
  TrackingCard({
    required this.title,
    required this.TripID,
    required this.pathCoords,
    required this.location1,
    required this.time1,
    required this.location2,
    required this.time2,
    required this.location3,
    required this.time3,
    required this.completeInfo,
    required this.stationIds,
    required this.stationNames,
    required this.driverName,
    required this.driverPhone,
    required this.helperName,
    required this.helperPhone,
  });

  @override
  _TrackingCardState createState() => _TrackingCardState();
}

class _TrackingCardState extends State<TrackingCard> {
  bool isExtended = false;
  Timer? locationUpdateTimer;

  Future<void> getlocationupdate(String TripID) async {
    var r = await Requests.post(globel.serverIp + 'getTripData',
        body: {
          'trip_id': TripID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
      var zz = r.json();
      widget.completeInfo = zz["time_list"];
      widget.pathCoords = zz['path'];
      // get current location
      // _getCurrentLocation();
    });
  }

  @override
  void initState() {
    super.initState();
    locationUpdateTimer =
        Timer.periodic(Duration(seconds: 10), (Timer timer) async {
      await getlocationupdate(widget.TripID);
      // x = cnv(widget.pathCoords);
    });
  }

  @override
  void dispose() {
    if (locationUpdateTimer != null && locationUpdateTimer!.isActive) {
      locationUpdateTimer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        width: 400.0, // Adjust the width as needed
        child: Card(
          elevation: 20,
          color: Color.fromARGB(255, 160, 88, 88),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Driver Helper Info Section
                if (globel.userType == "buet_staff")
                  Container(
                    child: DriverHelperInfo(
                      driverTitle: "Driver",
                      driverName: widget.driverName,
                      driverPhone: widget.driverPhone,
                      helperTitle: "Helper",
                      helperName: widget.helperName,
                      helperPhone: widget.helperPhone,
                    ),
                  ),
                SizedBox(height: 10),
                SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle Logo Section
                    Column(
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          size: 80,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Text color
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 8,
                    ), // Add spacing between Icon/Title and Stations

                    // Stations Section
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Extended Information Section
                          if (isExtended) ...[
                            // Show extended information if isExtended is true
                            Column(
                              children: [
                                for (int i = 0;
                                    i < widget.completeInfo.length;
                                    i++)
                                  Column(
                                    children: [
                                      CircleWidget(
                                        text1: widget.stationNames[widget
                                            .stationIds
                                            .indexOf(widget.completeInfo[i]
                                                ['station'])],
                                        text2: widget.completeInfo[i]['time'] !=
                                                null
                                            ? DateFormat('jm').format(
                                                DateTime.parse(
                                                        widget.completeInfo[i]
                                                            ['time'])
                                                    .toLocal())
                                            : "--",
                                        fromtrack: true,
                                      ),
                                      SizedBox(
                                          height:
                                              10), // Add spacing between CircleWidgets
                                    ],
                                  ),
                              ],
                            ),
                          ] else ...[
                            CircleWidget(
                                text1: widget.location1, text2: widget.time1),
                            SizedBox(height: 10),
                            CircleWidget(
                                text1: widget.location2, text2: widget.time2),
                            SizedBox(height: 10),
                            CircleWidget(
                                text1: widget.location3, text2: widget.time3),
                            SizedBox(height: 10),
                          ],

                          // Toggle button and Map button
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: isExtended
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          isExtended = !isExtended;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        side: const BorderSide(
                                          width: 1.0,
                                          color: Color.fromARGB(
                                              150, 255, 255, 255),
                                        ),
                                        backgroundColor:
                                            Color.fromARGB(255, 160, 88, 88),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: isExtended
                                          ? Icon(Icons.keyboard_arrow_up)
                                          : Icon(Icons.keyboard_arrow_down),
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Visibility(
                                      visible: isExtended,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          GoRouter.of(context)
                                              .push("/trackingmap", extra: {
                                            'TripID': widget.TripID,
                                            'pathCoords': widget.pathCoords,
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          side: const BorderSide(
                                            width: 1.0,
                                            color: Color.fromARGB(
                                                150, 255, 255, 255),
                                          ),
                                          backgroundColor:
                                              Color.fromARGB(255, 160, 88, 88),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: Icon(Icons.map),
                                        label: Text("Track on Map"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
