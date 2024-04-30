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
  final bool islive;
  final Function() parentReloadCallback;
  final Function() parentTabController;
  final Color buttonColor;
  final String title;
  final String Route;

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
      required this.title,
      required this.Route});

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

  // Map<String, String> getDateAndTime(String dateTimeString) {
  //   DateTime dateTime = DateTime.parse(dateTimeString);
  //   String formattedDate = DateFormat('yyyy-MM-dd').format(dateTime.toUtc());
  //   String formattedTime = DateFormat('HH:mm:ss').format(dateTime.toUtc());

  //   return {'Sdate': formattedDate, 'Stime': formattedTime};
  // }

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

  // // Function to send location updates
  // Future<void> _sendLocationUpdate(String tripID) async {
  //   await _getCurrentLocation();

  //   print(tripID);
  //   print(latitude.toString());
  //   print(longitude.toString());
  // }

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
    // context.loaderOverlay.show();
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

      // context.loaderOverlay.hide();
      return true;
    }
    // context.loaderOverlay.hide();
    return false;
  }

  Future<bool> onTripEnd(String tripID) async {
    // context.loaderOverlay.show();
    await _getCurrentLocation();

    var r2 = await Requests.post(globel.serverIp + 'endTrip',
        body: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r2.raiseForStatus();

    dynamic json2 = r2.json();
    print(json2);

    if (json2['success'] == true) {
      await globel.positionStream?.cancel();
      // context.loaderOverlay.hide();
      return true;
    }
    // context.loaderOverlay.hide();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    globel.printWarning("build");
    for (int i = 0; i < globel.routeNames.length; i++) {
      print(globel.routeNames[i]);
    }
    Duration remaining =
        DateTime.now().difference(DateTime.parse(widget.StartTime));
    Duration remaining2 = Duration();

    if (widget.EndTime != null) {
      try {
        DateTime endTime = DateTime.parse(widget.EndTime!);
        remaining2 = DateTime.now().difference(endTime);
      } catch (e) {
        print("Error parsing EndTime: $e");
        // Handle the parsing error, log it, or set remaining2 to a default value
      }
    }
    remaining = remaining.abs();
    remaining2 = remaining2.abs();
    running_trip = widget.islive;
    bool showWarning = !widget.islive;
    bool ended_trip = false;
    if (running_trip == false && widget.EndTime != "") {
      ended_trip = true;
      showWarning = false;
    }

    int start_hours = remaining.inHours;
    int start_minutes = (remaining.inMinutes % 60);

    int end_hours = remaining2.inHours;
    int end_minutes = (remaining2.inMinutes % 60);
    //bool running =  DateTime.now().isAfter(DateTime.parse(widget.StartTime)) && DateTime.now().isBefore(DateTime.parse(widget.EndTime));
    //if (remaining.inMinutes < 10) showWarning = true;

    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      // set color to 0xFFFFD5D6
      color: (widget.title == "End Trip" && widget.islive == true)
          ? Color.fromARGB(255, 222, 247, 234)
          : Color.fromARGB(255, 255, 222, 223),
      // add shadow to the card
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Container(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.islive && widget.EndTime != "")
                Container(
                  child: buildDataTable({
                    'Route': globel
                        .routeNames[globel.routeIDs.indexOf(widget.Route)],
                    'Trip #': widget.TripID,
                    'Start Date': DateTime.parse(widget.StartTime)
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    'Start Time': DateFormat('h:mm a')
                        .format(DateTime.parse(widget.StartTime).toLocal()),
                    'End Date': DateTime.parse(widget.EndTime!)
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    'End Time': DateFormat('h:mm a')
                        .format(DateTime.parse(widget.EndTime!).toLocal()),
                    'Bus No': widget.BusNo,
                  }),
                ),
              if (widget.islive || widget.EndTime == "")
                Container(
                  child: buildDataTable({
                    'Route': globel
                        .routeNames[globel.routeIDs.indexOf(widget.Route)],
                    'Trip #': widget.TripID,
                    'Start Date': DateTime.parse(widget.StartTime)
                        .toLocal()
                        .toString()
                        .split(' ')
                        .first,
                    'Start Time': DateFormat('h:mm a')
                        .format(DateTime.parse(widget.StartTime).toLocal()),
                    'Bus No': widget.BusNo,
                  }),
                ),
              SizedBox(height: 16),
              if (showWarning)
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.red,
                    ),
                    SizedBox(
                        width:
                            8), // Adjust the spacing between the icon and the text as needed
                    Expanded(
                      child: Text(
                        'Trip Scheduled in $start_hours hours and $start_minutes minutes from now',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              if (running_trip)
                Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: Color.fromARGB(255, 4, 154, 94),
                    ),
                    SizedBox(
                        width:
                            8), // Adjust the spacing between the icon and the text as needed
                    Expanded(
                      child: Text(
                        'The trip is running currently for $start_hours hours and $start_minutes minutes',
                        style: TextStyle(
                          color: Color.fromARGB(255, 4, 154, 94),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              if (ended_trip && end_minutes != 0)
                Text(
                  'The trip is finished $end_hours hours and $end_minutes minutes ago',
                  textAlign: TextAlign.center, // Center the text
                  style: TextStyle(
                    color: Color.fromARGB(255, 0, 9, 5).withOpacity(0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (ended_trip && end_minutes == 0)
                Text(
                  'The trip is finished',
                  textAlign: TextAlign.center, // Center the text
                  style: TextStyle(
                    color: Color.fromARGB(255, 4, 154, 94),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              SizedBox(height: 20),
              Center(
                child: // show the button only if title is "Upcoming Trip" or title is "Ongoing trip" and islive is true

                    (globel.staffRole == 'driver' &&
                            ((widget.title == "Start Trip" &&
                                    globel.runningTripId == "") ||
                                (widget.title == "End Trip" &&
                                    widget.islive == true)))
                        ? ElevatedButton(
                            onPressed: () async {
                              // Check if location services are enabled
                              context.loaderOverlay.show();
                              bool isLocationEnabled =
                                  await _getCurrentLocation();

                              if (isLocationEnabled) {
                                globel.runningTripId = widget.TripID;
                                // Location services are enabled, proceed with the action
                                if (widget.title == "Start Trip") {
                                  bool startTrip =
                                      await onTripStart(globel.runningTripId);
                                  if (startTrip) {
                                    // Workmanager()
                                    //     .registerOneOffTask("bus", "sojib");
                                    late LocationSettings locationSettings;

                                    locationSettings = AndroidSettings(
                                        accuracy: LocationAccuracy.high,
                                        distanceFilter: globel.distanceFilter,
                                        forceLocationManager: true,
                                        intervalDuration: const Duration(
                                            seconds: globel.updateInterval),
                                        //(Optional) Set foreground notification config to keep the app alive
                                        //when going to the background
                                        foregroundNotificationConfig:
                                            const ForegroundNotificationConfig(
                                          notificationText:
                                              "BusBuddy app will continue to receive your location even when you aren't using it",
                                          notificationTitle:
                                              "Running in Background",
                                          enableWakeLock: true,
                                        ));

                                    globel.positionStream =
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
                                  } else {
                                    globel.runningTripId = "";
                                    // fluttertoast
                                    Fluttertoast.showToast(
                                        msg: "A trip is already ongoing",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.BOTTOM,
                                        timeInSecForIosWeb: 1,
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                        fontSize: 16.0);
                                  }
                                } else if (widget.title == "End Trip") {
                                  bool endTrip =
                                      await onTripEnd(globel.runningTripId);
                                  if (endTrip) {
                                    globel.runningTripId = "";
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
                              context.loaderOverlay.hide();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: widget.buttonColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                                fixedSize: Size(200, 50)),
                            child: Text(widget.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                )),
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
  return Table(
    columnWidths: {
      0: FlexColumnWidth(2), // Adjust the width of the first column
      1: FlexColumnWidth(5), // Adjust the width of the second column
    },
    children: data.entries.map((entry) {
      return TableRow(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${entry.key}:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${entry.value}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black.withOpacity(0.5),
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    }).toList(),
  );
}
