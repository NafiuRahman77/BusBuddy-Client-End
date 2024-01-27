import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;
import 'dart:async'; // Import this for Timer

// final LocationSettings locationSettings = LocationSettings(
//   accuracy: LocationAccuracy.high,
//   distanceFilter: 100,
// );

class TripCard extends StatefulWidget {
  final String SourceLocation;
  final String DestinationLocation;
  final String StartTime;
  final String? EndTime;
  final String BusNo;
  final String TripID;
  final String PrevP;
  bool islive;
  final Function() parentReloadCallback;
  final Function() parentTabController;
  final Color buttonColor;
  final String title;

  TripCard(
      {required this.SourceLocation,
      required this.DestinationLocation,
      required this.StartTime,
      this.EndTime,
      required this.BusNo,
      required this.TripID,
      required this.PrevP,
      required this.islive,
      required this.parentReloadCallback,
      required this.parentTabController,
      required this.buttonColor,
      required this.title});

  @override
  _TripCardState createState() => _TripCardState();
}

class _TripCardState extends State<TripCard>
    with AutomaticKeepAliveClientMixin {
  bool running_trip = false;
  Color buttonColor = Colors.green;

  String buttonText1 = "Turn On GPS";
  String buttonText2 = "Turn Off GPS";

  String buttontxt = "Turn On GPS";

  Timer? locationUpdateTimer; // Timer to periodically send location updates
  double? latitude;
  double? longitude;

  @override
  bool get wantKeepAlive => true;

  Map<String, String> getDateAndTime(String dateTimeString) {
    DateTime dateTime = DateTime.parse(dateTimeString);
    String formattedDate = DateFormat('yyyy-MM-dd').format(dateTime.toUtc());
    String formattedTime = DateFormat('HH:mm:ss').format(dateTime.toUtc());

    return {'Sdate': formattedDate, 'Stime': formattedTime};
  }

  // Function to get the current location
  Future<bool> _getCurrentLocation() async {
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    // print(isLocationServiceEnabled);

    if (!isLocationServiceEnabled) {
      // Handle the case where location services are not enabled
      // You may want to show a toast or display a message
      print('Location services are not enabled.');
      Fluttertoast.showToast(
        msg: "Please enable location services.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return false;
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
        return false;
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
      return true;
    } catch (e) {
      print("Error getting location: $e");
      return false;
    }
  }

  // Function to send location updates
  Future<void> _sendLocationUpdate(String tripID) async {
    await _getCurrentLocation();

    print(tripID);
    print(latitude.toString());
    print(longitude.toString());
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Function to stop the timer for location updates
  void stopLocationUpdateTimer() {
    // cancel the timer if it is not null
    if (locationUpdateTimer != null) {
      locationUpdateTimer!.cancel();
      locationUpdateTimer = null;
    }
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

      // locationUpdateTimer = Timer.periodic(Duration(seconds: 2), (Timer timer) {
      //   _sendLocationUpdate(tripID);
      // });

      context.loaderOverlay.hide();
      return true;
    }
    context.loaderOverlay.hide();
    return false;
  }

  Future<bool> onTripEnd(String tripID) async {
    context.loaderOverlay.show();
    await _getCurrentLocation();

    var r2 = await Requests.post(globel.serverIp + 'endTrip',
        body: {
          'trip_id': tripID,
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r2.raiseForStatus();

    dynamic json2 = r2.json();
    print(json2);

    if (json2['success'] == true) {
      context.loaderOverlay.hide();
      return true;
    }
    context.loaderOverlay.hide();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // print(widget.SourceLocation);

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
                child: // show the button only if title is "Upcoming Trip" or title is "Ongoing trip" and islive is true

                    (widget.title == "Start Trip" ||
                            (widget.title == "End Trip" &&
                                widget.islive == true))
                        ? ElevatedButton(
                            onPressed: () async {
                              // Check if location services are enabled
                              bool isLocationEnabled =
                                  await _getCurrentLocation();

                              if (isLocationEnabled) {
                                // Location services are enabled, proceed with the action
                                if (widget.title == "Start Trip") {
                                  bool startTrip =
                                      await onTripStart(widget.TripID);

                                  // Workmanager()
                                  //     .registerOneOffTask("bus", "sojib");
                                  late LocationSettings locationSettings;

                                  locationSettings = AndroidSettings(
                                      accuracy: LocationAccuracy.high,
                                      distanceFilter: 100,
                                      forceLocationManager: true,
                                      intervalDuration:
                                          const Duration(seconds: 10),
                                      //(Optional) Set foreground notification config to keep the app alive
                                      //when going to the background
                                      foregroundNotificationConfig:
                                          const ForegroundNotificationConfig(
                                        notificationText:
                                            "Example app will continue to receive your location even when you aren't using it",
                                        notificationTitle:
                                            "Running in Background",
                                        enableWakeLock: true,
                                      ));

                                  StreamSubscription<Position> positionStream =
                                      Geolocator.getPositionStream(
                                              locationSettings:
                                                  locationSettings)
                                          .listen((Position? position) async {
                                    print(position == null
                                        ? 'Unknown'
                                        : '${position.latitude.toString()}, ${position.longitude.toString()}');

                                    if (position != null) {
                                      var r2 = await Requests.post(
                                          globel.serverIp +
                                              'updateStaffLocation',
                                          body: {
                                            'trip_id': widget.TripID,
                                            'latitude':
                                                position.latitude.toString(),
                                            'longitude':
                                                position.longitude.toString(),
                                          },
                                          bodyEncoding: RequestBodyEncoding
                                              .FormURLEncoded);

                                      r2.raiseForStatus();
                                    }
                                  });
                                  widget.parentTabController();
                                  await widget.parentReloadCallback();
                                } else if (widget.title == "End Trip") {
                                  bool endTrip = await onTripEnd(widget.TripID);
                                  if (endTrip) {
                                    print("ebdbdbdbdbedbdbd");
                                    widget.parentTabController();
                                    await widget.parentReloadCallback();
                                  }
                                }
                              } else {
                                //stopLocationUpdateTimer();
                                // bool endTrip = await onTripEnd(widget.TripID);
                                // await widget.parentReloadCallback();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              primary: widget.buttonColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(widget.title),
                          )
                        : SizedBox.shrink(),
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
