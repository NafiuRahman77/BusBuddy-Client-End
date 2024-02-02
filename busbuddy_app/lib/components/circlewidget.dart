import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../globel.dart' as globel;

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
