import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

class CircleWidget extends StatelessWidget {
  final String text1;
  final String text2;
  final bool fromtrack;

  CircleWidget({
    required this.text1,
    required this.text2,
    this.fromtrack = false,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color circColor = Colors.grey;
    if (fromtrack) {
      DateTime? entryTime;
      DateTime currentTime = DateTime.now();

      if (text2 != "--") {
        entryTime = DateFormat.jm().parse(text2);
        int entryMinutes = entryTime.hour * 60 + entryTime.minute;
        int currentMinutes = currentTime.hour * 60 + currentTime.minute;

        // Calculate the difference in minutes
        int differenceInMinutes = currentMinutes - entryMinutes;
        print(differenceInMinutes);
        if (differenceInMinutes <= 68) {
          circColor = Colors.red;
        }
      }
      textColor = entryTime != null && entryTime.isBefore(currentTime)
          ? const Color.fromARGB(255, 254, 237, 84)
          : Color.fromARGB(255, 177, 245, 129);
    } else {
      textColor = Colors.white;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8.0,
          height: 10.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circColor, // Circle color
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
                  color: Colors.white,
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
