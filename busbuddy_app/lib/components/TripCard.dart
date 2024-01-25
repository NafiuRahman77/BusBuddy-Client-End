import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;
import 'dart:async'; // Import this for Timer

class TripCard extends StatefulWidget {
  final String SourceLocation;
  final String DestinationLocation;
  final String StartTime;
  final String? EndTime;
  final String BusNo;
  final String TripID;
  final String PrevP;
  final bool islive;

  TripCard({
    required this.SourceLocation,
    required this.DestinationLocation,
    required this.StartTime,
    this.EndTime,
    required this.BusNo,
    required this.TripID,
    required this.PrevP,
    required this.islive,
  });

  @override
  _TripCardState createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool running_trip = false;
  Color buttonColor = Colors.green;

  String buttonText1 = "Turn On GPS";
  String buttonText2 = "Turn Off GPS";

  String buttontxt = "Turn On GPS";

  Timer? locationUpdateTimer; // Timer to periodically send location updates
  double? latitude;
  double? longitude;

  Map<String, String> getDateAndTime(String dateTimeString) {
    DateTime dateTime = DateTime.parse(dateTimeString);
    String formattedDate = DateFormat('yyyy-MM-dd').format(dateTime.toUtc());
    String formattedTime = DateFormat('HH:mm:ss').format(dateTime.toUtc());

    return {'Sdate': formattedDate, 'Stime': formattedTime};
  }

  // Function to get the current location
  Future<void> _getCurrentLocation() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      // Handle the case where location services are not enabled
      // You may want to show a dialog or redirect the user to the device settings
      print('Location services are not enabled.');
      return;
    }

    // Check if the app has location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request location permission
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        // Handle the case where the user denied location permission
        print('User denied location permission.');
        return;
      }
    }
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  // Function to send location updates
  Future<void> _sendLocationUpdate(String tripID) async {
    await _getCurrentLocation();

    // var r = await Requests.post(globel.serverIp + 'updateLocation',
    //     body: {
    //       'trip_id': tripID,
    //       'latitude': latitude.toString(),
    //       'longitude': longitude.toString(),
    //     },
    //     bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    // r.raiseForStatus();
    print(tripID);
    print(latitude.toString());
    print(longitude.toString());
  }

  @override
  void dispose() {
    locationUpdateTimer
        ?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Function to stop the timer for location updates
  void stopLocationUpdateTimer() {
    locationUpdateTimer?.cancel();
  }

  Future<bool> onTripStart(String tripID) async {
    context.loaderOverlay.show();
    // Get initial location
    await _getCurrentLocation();

    var r2 = await Requests.post(globel.serverIp + 'startTrip',
        body: {
          'trip_id': tripID,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    print(tripID);
    print(latitude.toString());
    print(longitude.toString());

    r2.raiseForStatus();

    dynamic json2 = r2.json();
    //print(json2);

    if (json2['success'] == true) {
      // Start the timer for location updates
      locationUpdateTimer =
          Timer.periodic(Duration(seconds: 10), (Timer timer) {
        _sendLocationUpdate(tripID);
      });

      context.loaderOverlay.hide();
      return true;
    }
    context.loaderOverlay.hide();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    print(widget.SourceLocation);

    Map<String, String> Sdt = getDateAndTime(widget.StartTime);
    Map<String, String> Ddt = getDateAndTime(widget.EndTime!);

    Duration remaining =
        DateTime.now().difference(DateTime.parse(widget.StartTime));
    bool showWarning = false;
    if (remaining.inMinutes < 10) showWarning = true;

    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: () {
          // Add functionality for the tap event
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: buildDataTable({
                  'Source': widget.SourceLocation,
                  'Destination': widget.DestinationLocation,
                  'Start Date': Sdt['Sdate']!,
                  'Start Time': Sdt['Stime']!,
                  'End Date': Ddt['Sdate']!,
                  'End Time': Ddt['Stime']!,
                  'Bus No': widget.BusNo,
                }),
              ),
              SizedBox(height: 16),
              if (showWarning)
                Text(
                  'Trip Scheduled in ${remaining.inMinutes} from now',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              if (running_trip)
                Text(
                  'The trip is running currenlty',
                  style: TextStyle(
                    color: Color.fromARGB(255, 38, 194, 27),
                  ),
                ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // bool startTrip = await onTripStart(widget.TripID);

                    if (running_trip) {
                      setState(() {
                        running_trip = !running_trip;
                        buttonColor = running_trip ? Colors.red : Colors.green;
                        buttontxt = running_trip ? buttonText2 : buttonText1;
                      });
                      stopLocationUpdateTimer();
                    } else {
                      // Turn On GPS button clicked
                      bool startTrip = await onTripStart(widget.TripID);
                      if (startTrip) {
                        setState(() {
                          running_trip = !running_trip;
                          buttonColor =
                              running_trip ? Colors.red : Colors.green;
                          buttontxt = running_trip ? buttonText2 : buttonText1;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    primary: buttonColor,
                    onPrimary: Colors.white,
                  ),
                  child: Text(buttontxt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildDataTable(Map<String, String> data) {
  List<DataRow> rows = [];

  data.forEach((label, value) {
    rows.add(buildDataRow(label, value));
  });

  return DataTable(
    dataRowHeight: 50, // Adjust the row height as needed
    columns: [
      DataColumn(
        label: SizedBox.shrink(), // Hide the header
      ),
      DataColumn(
        label: SizedBox.shrink(), // Hide the header
      ),
    ],
    rows: rows,
  );
}

DataRow buildDataRow(String label, String value) {
  return DataRow(
    cells: [
      DataCell(
        Center(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataCell(
        Center(
          child: Text(value),
        ),
      ),
    ],
  );
}
