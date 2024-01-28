import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

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
            child: Row(
              // Changed from Column to Row
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Icon and Title Section
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
                        color: Colors.white, // Text color
                      ),
                    ),
                  ],
                ),
                SizedBox(
                    width: 8), // Add spacing between Icon/Title and Stations
                // Stations Section
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isExtended) ...[
                        // Show extended information if isExtended is true
                        Column(
                          children: [
                            for (int i = 0; i < widget.extendedInfo.length; i++)
                              Column(
                                children: [
                                  CircleWidget(
                                    text1: widget.stationNames[widget.stationIds
                                        .indexOf(
                                            widget.extendedInfo[i]['station'])],
                                    text2: DateFormat('jm').format(
                                        DateTime.parse(
                                                widget.extendedInfo[i]['time'])
                                            .toLocal()),
                                  ),
                                  SizedBox(
                                      height:
                                          10), // Add spacing between CircleWidgets
                                ],
                              ),
                          ],
                        ),
                      ] else ...[
                        // Show original content if isExtended is false
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
                      // Toggle button
                      Center(
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isExtended =
                                      !isExtended; // Toggle the card state
                                  print(widget.extendedInfo);
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                side: const BorderSide(
                                    width: 1.0,
                                    color: Color.fromARGB(150, 255, 255, 255)),
                                backgroundColor: Color.fromARGB(255, 160, 88,
                                    88), // Set the background color
                                foregroundColor:
                                    Colors.white, // Set the icon color to white
                              ),
                              child: isExtended
                                  ? Icon(Icons
                                      .keyboard_arrow_up) // Show "Expand Less" icon
                                  : Icon(Icons
                                      .keyboard_arrow_down), // Show "Expand More" icon
                            ),
                            Spacer(),
                            Visibility(
                              visible:
                                  isExtended, // Show the button when isExtended is true
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Set<Marker> jMarkerSet = Set<Marker>();
                                  widget.extendedInfo.forEach((stop) {
                                    if (stop['coord'] != null)
                                      jMarkerSet.add(Marker(
                                        markerId: MarkerId("value"),
                                        position: LatLng(stop['coord']['x'],
                                            stop['coord']['y']),
                                      ));
                                  });
                                  GoRouter.of(context)
                                      .push("/routetimemap", extra: jMarkerSet);
                                },
                                style: ElevatedButton.styleFrom(
                                  side: const BorderSide(
                                      width: 1.0,
                                      color:
                                          Color.fromARGB(150, 255, 255, 255)),
                                  backgroundColor: Color.fromARGB(255, 160, 88,
                                      88), // Set the background color
                                  foregroundColor: Colors
                                      .white, // Set the icon color to white
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
          ),
        ),
      ),
    );
  }
}

class CircleWidget extends StatelessWidget {
  final String text1;
  final String text2;
  int x = 0;

  CircleWidget({required this.text1, required this.text2, this.x = 0});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey, // Circle color
          ),
        ),
        SizedBox(width: 12.0), // Space between circle and text
        Expanded(
          child: Row(
            // Use Row instead of Column
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: x == 0 ? Colors.white : Colors.black,
                  fontSize: 12.0,
                ),
              ),
              if (text2.isNotEmpty)
                SizedBox(width: 10.0), // Add some space between text1 and text2
              Spacer(),
              Text(
                text2,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
