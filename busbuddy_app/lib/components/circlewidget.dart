import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

class CircleWidget extends StatelessWidget {
  final String text1;
  final String text2;
  final bool defRoute;
  CircleWidget({
    required this.text1,
    required this.text2,
    this.defRoute = false,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor = Colors.white;
    Color circColor = Colors.white;
    // if (fromtrack) {
    //   DateTime? entryTime;
    //   DateTime currentTime = DateTime.now();

    //   if (text2 != "--") {
    //     entryTime = DateFormat.jm().parse(text2);
    //     int entryMinutes = entryTime.hour * 60 + entryTime.minute;
    //     int currentMinutes = currentTime.hour * 60 + currentTime.minute;

    //     // Calculate the difference in minutes
    //     int differenceInMinutes = currentMinutes - entryMinutes;
    //     print(differenceInMinutes);
    //     if (differenceInMinutes <= 68) {
    //       circColor = Colors.red;
    //     }
    //   }
    //   textColor = entryTime != null && entryTime.isBefore(currentTime)
    //       ? const Color.fromARGB(255, 254, 237, 84)
    //       : Color.fromARGB(255, 177, 245, 129);
    // } else {
    //   textColor = Colors.white;
    // }
    if (text2 != "" && text2[0] != '~' && text2 != "--") {
      circColor = Color.fromARGB(255, 177, 245, 129);
      textColor = Color.fromARGB(255, 177, 245, 129);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 4.0), // Space between circle and text

        Icon(
          defRoute
              ? Icons.radio_button_checked
              : ((text2 != "" && text2[0] != '~')
                  ? Icons.circle
                  : Icons.trip_origin),
          color: circColor,
          size: 15.0,
        ),
        SizedBox(width: 8.0), // Space between circle and text
        Expanded(
          child: Row(
            // Use Row instead of Column
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  fontSize: 13.0,
                ),
              ),
              if (text2.isNotEmpty)
                SizedBox(width: 10.0), // Add some space between text1 and text2
              Spacer(),
              Text(
                text2,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: (text2 != "" && text2[0] == '~')
                      ? Color.fromARGB(255, 197, 148, 148)
                      : Colors.white,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
