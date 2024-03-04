import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHelperInfo extends StatelessWidget {
  final String driverTitle;
  final String driverName;
  final String driverPhone;
  final String helperTitle;
  final String helperName;
  final String helperPhone;

  const DriverHelperInfo({
    required this.driverTitle,
    required this.driverName,
    required this.driverPhone,
    required this.helperTitle,
    required this.helperName,
    required this.helperPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    driverTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Change text color to white
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.person,
                    size: 12,
                    color: Colors.red,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '$driverName',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Change text color to white
                    ),
                  ),
                  Spacer(), // Add a spacer to push the IconButton to the right
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color.fromARGB(255, 97, 187, 100),
                      border: Border.all(color: Colors.grey), // Add gray border
                    ),
                    width: 30,
                    child: IconButton(
                      icon: Icon(Icons.call),
                      color: Colors.white,
                      iconSize: 12,
                      onPressed: () async {
                        final Uri callurl = Uri(
                          scheme: 'tel',
                          path: driverPhone,
                        );
                        if (await canLaunchUrl(callurl))
                          await launchUrl(callurl);
                        else
                          Fluttertoast.showToast(
                            msg: "Can't make call",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          // SizedBox(height: 10),
          // Helper Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    helperTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.person,
                    size: 12,
                    color: Colors.red,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '$helperName',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Change text color to white
                    ),
                  ),
                  Spacer(), // Add a spacer to push the IconButton to the right
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color.fromARGB(255, 97, 187, 100),
                      border: Border.all(color: Colors.grey),
                      // Add gray border
                    ),
                    width: 30,
                    child: IconButton(
                      icon: Icon(Icons.call),
                      // set icon color
                      color: Colors.white,
                      iconSize: 12,
                      onPressed: () async {
                        final Uri callurl = Uri(
                          scheme: 'tel',
                          path: helperPhone,
                        );
                        if (await canLaunchUrl(callurl))
                          await launchUrl(callurl);
                        else
                          Fluttertoast.showToast(
                            msg: "Can't make call",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
