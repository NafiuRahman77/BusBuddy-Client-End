import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;
import './circlewidget.dart';
import '../components/driverHelperInfo.dart';

class CustomCard extends StatefulWidget {
  final String title;
  final String location1;
  final String time1;
  final String location2;
  final String time2;
  final String location3;
  final String time3;
  final List<dynamic> extendedInfo; // List of additional information
  final List<String> stationIds;
  final List<String> stationNames;
  final List<dynamic> stationCoords;
  final String driverName;
  final String driverPhone;
  final String helperName;
  final String helperPhone;

  CustomCard({
    required this.title,
    required this.location1,
    required this.time1,
    required this.location2,
    required this.time2,
    required this.location3,
    required this.time3,
    required this.extendedInfo,
    required this.stationIds,
    required this.stationNames,
    required this.stationCoords,
    required this.driverName,
    required this.driverPhone,
    required this.helperName,
    required this.helperPhone,
  });

  @override
  _CustomCardState createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool isExtended = false; // Track whether the card is extended or not
  List<dynamic> routeCoords = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (isExtended) ...[
                          Column(
                            children: [
                              for (int i = 0;
                                  i < widget.extendedInfo.length;
                                  i++)
                                Column(
                                  children: [
                                    CircleWidget(
                                      text1: widget.stationNames[widget
                                          .stationIds
                                          .indexOf(widget.extendedInfo[i]
                                              ['station'])],
                                      text2: DateFormat('jm').format(
                                          DateTime.parse(widget.extendedInfo[i]
                                                  ['time'])
                                              .toLocal()),
                                    ),
                                    SizedBox(height: 10),
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
                        Center(
                          child: Row(
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
                                      color:
                                          Color.fromARGB(150, 255, 255, 255)),
                                  backgroundColor:
                                      Color.fromARGB(255, 160, 88, 88),
                                  foregroundColor: Colors.white,
                                ),
                                child: isExtended
                                    ? Icon(Icons.keyboard_arrow_up)
                                    : Icon(Icons.keyboard_arrow_down),
                              ),
                              Spacer(),
                              Visibility(
                                visible: isExtended,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Set<Marker> jMarkerSet = Set<Marker>();
                                    for (dynamic stop in widget.extendedInfo) {
                                      if (stop['coord'] != null)
                                        jMarkerSet.add(Marker(
                                          markerId: MarkerId("value"),
                                          position: LatLng(stop['coord']['x'],
                                              stop['coord']['y']),
                                          infoWindow: InfoWindow(
                                            title: widget.stationNames[widget
                                                .stationIds
                                                .indexOf(stop['station'])],
                                            snippet: stop["time"] != null
                                                ? DateFormat('jm').format(
                                                    DateTime.parse(stop["time"])
                                                        .toLocal())
                                                : "--",
                                          ),
                                        ));
                                    }
                                    GoRouter.of(context).push("/routetimemap",
                                        extra: jMarkerSet);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    side: const BorderSide(
                                        width: 1.0,
                                        color:
                                            Color.fromARGB(150, 255, 255, 255)),
                                    backgroundColor:
                                        Color.fromARGB(255, 160, 88, 88),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: Icon(Icons.map),
                                  label: Text("Show map"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
