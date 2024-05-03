import 'dart:async';
import 'dart:convert';
import 'package:busbuddy_app/components/GradientIcon.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;
import './circlewidget.dart';
import '../components/driverHelperInfo.dart';
import 'package:geolocator/geolocator.dart';

class TrackingCard extends StatefulWidget {
  // final String title;
  String TripID = "";
  // List<dynamic> pathCoords = List.empty();
  // final String location1;
  // final String time1;
  // final String location2;
  // final String time2;
  // final String location3;
  // final String time3;
  // String passengerCount;
  // List<dynamic> completeInfo;
  final List<String> stationIds;
  final List<String> stationNames;
  final String driverName;
  final String driverPhone;
  final String helperName;
  final String helperPhone;
  final List<dynamic> stationCoords;
  final bool isUserRoute;
  // final List<dynamic> timeWindow;
  List<String> timeList = List.empty();
  TrackingCard({
    // required this.title,
    required this.TripID,
    // required this.pathCoords,
    // required this.location1,
    // required this.time1,
    // required this.location2,
    // required this.time2,
    // required this.location3,
    // required this.time3,
    // required this.completeInfo,
    required this.stationIds,
    required this.stationNames,
    required this.driverName,
    required this.driverPhone,
    required this.helperName,
    required this.helperPhone,
    // required this.passengerCount,
    // required this.timeWindow,
    required this.stationCoords,
    required this.isUserRoute,
  });

  @override
  _TrackingCardState createState() => _TrackingCardState();
}

class _TrackingCardState extends State<TrackingCard> {
  int defaultRouteIdx = -1;
  bool isExtended = false, isStalled = false;
  Timer? locationUpdateTimer;
  List<dynamic> completeInfo = [];
  List<dynamic> pathCoords = [];
  String passengerCount = "";
  String busNo = "";
  List<dynamic> timeWindow = [];
  String st1 = "", t1 = "", st2 = "", t2 = "", st3 = "", t3 = "";

  Future<void> getlocationupdate(String TripID) async {
    var r = await Requests.post(globel.serverIp + 'getTripData',
        body: {
          'trip_id': TripID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);
    print("hi from rangeError");

    r.raiseForStatus();
    var zz = await r.json();
    if (r.statusCode == 401) {
      await Requests.clearStoredCookies(globel.serverAddr);
      globel.clearAll();
      Fluttertoast.showToast(
          msg: 'Not authenticated / authorised.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(71, 211, 59, 45),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      GoRouter.of(context).go("/login");
      return;
    }
    setState(() {
      completeInfo = zz["time_list"];

      for (int j = 0; j < completeInfo.length; j++) {
        if (completeInfo[j]['time'] == null) {
          completeInfo[j]['time'] = "--";
        }
      }
      pathCoords = zz['path'];
      passengerCount = zz['passenger_count'].toString();
      timeWindow = zz['time_window'];
      busNo = zz['bus'];
    });
  }

  Future<void> formatTimes() async {
    for (int i = 0; i < completeInfo.length; i++) {
      if (completeInfo[i]['time'] == null || completeInfo[i]['time'] == "--") {
        continue;
      }
      String time =
          // DateTime.fromMillisecondsSinceEpoch(nextT).toIso8601String();
          await DateFormat('jm')
              .format(await DateTime.parse(completeInfo[i]['time']).toLocal());
      if (completeInfo[i]['pred'] != null && completeInfo[i]['pred'] == true) {
        time = "~" + time;
      }
      setState(() {
        completeInfo[i]['time'] = time;
      });
    }
    setState(() {
      st1 = widget
          .stationNames[widget.stationIds.indexOf(completeInfo[0]['station'])];
      t1 = completeInfo[0]['time'];
      int midIdx = (defaultRouteIdx == -1 ||
              defaultRouteIdx == 0 ||
              defaultRouteIdx == completeInfo.length - 1)
          ? completeInfo.length ~/ 2
          : defaultRouteIdx;
      st2 = widget.stationNames[
          widget.stationIds.indexOf(completeInfo[midIdx]['station'])];
      t2 = completeInfo[midIdx]['time'];
      st3 = widget.stationNames[widget.stationIds
          .indexOf(completeInfo[completeInfo.length - 1]['station'])];
      t3 = completeInfo[completeInfo.length - 1]['time'];
    });
  }

  Future<void> predictTimes() async {
    double d = 0;
    int ps = pathCoords.length;
    int ts = timeWindow.length;
    if (ts > 2) {
      if (DateTime.parse(timeWindow[timeWindow.length - 1])
              .difference(DateTime.now())
              .inMinutes <=
          -20) {
        setState(() {
          isStalled = true;
        });
      } else {
        double delay = DateTime.now()
                .difference(DateTime.parse(timeWindow[timeWindow.length - 1]))
                .inMilliseconds *
            1.2;

        for (int i = ps - 1; i > ps - ts; i--) {
          double delta = Geolocator.distanceBetween(
              double.parse(pathCoords[i]['latitude'].toString()),
              double.parse(pathCoords[i]['longitude'].toString()),
              double.parse(pathCoords[i - 1]['latitude'].toString()),
              double.parse(pathCoords[i - 1]['longitude'].toString()));
          d += delta;
          print(delta);
        }
        double t9 =
            (DateTime.parse(timeWindow[ts - 1]).millisecondsSinceEpoch) * 0.001;
        double t0 =
            (DateTime.parse(timeWindow[0]).millisecondsSinceEpoch) * 0.001;
        double delT = t9 - t0;
        print(delT);
        double speed = d / delT;
        print("velocity: $speed");
        // print(completeInfo);
        int j = -1;
        for (int i = 0; i < completeInfo.length; i++) {
          print("hiiii");
          print(completeInfo[i]);
          if (i > 0 &&
              (completeInfo[i]['time'] == null ||
                  completeInfo[i]['time'] == "--")) {
            if (j == -1) j = 0;
            double prevT = (DateTime.parse(completeInfo[i - 1]['time'])
                    .millisecondsSinceEpoch) *
                0.001;
            print(prevT);
            dynamic prevCoord = widget.stationCoords[
                widget.stationIds.indexOf(completeInfo[i - 1]['station'])];
            print(prevCoord);
            dynamic nextCoord = widget.stationCoords[
                widget.stationIds.indexOf(completeInfo[i]['station'])];
            print(nextCoord);
            double distance = await Geolocator.distanceBetween(
                double.parse(prevCoord['x'].toString()),
                double.parse(prevCoord['y'].toString()),
                double.parse(nextCoord['x'].toString()),
                double.parse(nextCoord['y'].toString()));
            double deltaT = distance / speed;
            if (deltaT / 3600 < 4) {
              int nextT = ((prevT + deltaT) * 1000 + delay).toInt();
              if (j == 0) {
                nextT = (nextT + delay).toInt();
                j = 1;
              }
              setState(() {
                completeInfo[i]['time'] =
                    DateTime.fromMillisecondsSinceEpoch(nextT)
                        .toIso8601String();
                completeInfo[i]['pred'] = true;
              });
              // print(completeInfo[i]['time']);
            } else {
              break;
            }
          } else {
            setState(() {
              completeInfo[i]['pred'] = false;
            });
          }
        }
      }
    }
    await formatTimes();
  }

  Future<void> initCard() async {
    context.loaderOverlay.show();
    print("innit");
    try {
      await getlocationupdate(widget.TripID);
      if (widget.isUserRoute) {
        for (int i = 0; i < completeInfo.length; i++) {
          if (completeInfo[i]['station'] == globel.userDefaultStationId) {
            defaultRouteIdx = i;
          }
        }
      }
      await predictTimes();

      locationUpdateTimer =
          Timer.periodic(Duration(seconds: 5), (Timer timer) async {
        try {
          await getlocationupdate(widget.TripID);
          await predictTimes();
        } catch (err) {
          globel.printError(err.toString());
          // context.loaderOverlay.hide();
          Fluttertoast.showToast(
              msg: 'Failed to reach server. Check your connection.',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Color.fromARGB(209, 194, 16, 0),
              textColor: Colors.white,
              fontSize: 16.0);
          // GoRouter.of(context).pop();
        }
      });
    } catch (err) {
      globel.printError(err.toString());
      context.loaderOverlay.hide();
      Fluttertoast.showToast(
          msg: 'Failed to reach server. Check your connection.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(209, 194, 16, 0),
          textColor: Colors.white,
          fontSize: 16.0);
    }
    context.loaderOverlay.hide();
  }

  @override
  void initState() {
    super.initState();

    initCard();
    // x = cnv(pathCoords);
    // print(element);
  }

  @override
  void dispose() {
    if (locationUpdateTimer != null && locationUpdateTimer!.isActive) {
      locationUpdateTimer!.cancel();
    }
    super.dispose();
  }

  List<dynamic> sendTimeList() {
    return completeInfo;
  }

  List<dynamic> sendPathCoords() {
    return pathCoords;
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
                  Column(
                    children: [
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
                      SizedBox(height: 15)
                    ],
                  ),
                SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circle Logo Section
                    Column(
                      children: [
                        GradientIcon(
                          iconData: Icons.directions_bus_rounded,
                          gradient: LinearGradient(
                            begin: Alignment.bottomRight,
                            end: Alignment.topLeft,
                            colors: [
                              Colors.black,
                              Color.fromARGB(255, 121, 12, 12)
                            ],
                          ),
                          size: 70.0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          busNo,
                          style: GoogleFonts.barlow(
                            textStyle: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.white, // Text color
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isExtended) ...[
                          Icon(
                            Icons.groups,
                            size: 40,
                            color: Color.fromARGB(255, 177, 245, 129),
                          ),
                          // Add spacing between Icon and Text
                          SizedBox(
                            width: 10,
                          ), // Add spacing between Icon and Text
                          Text(
                            "$passengerCount onboard",
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(
                                  255, 177, 245, 129), // Text color
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(
                      width: 10,
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
                                for (int i = 0; i < completeInfo.length; i++)
                                  Column(
                                    children: [
                                      CircleWidget(
                                        text1: widget.stationNames[
                                            widget.stationIds.indexOf(
                                                completeInfo[i]['station'])],
                                        text2: completeInfo[i]['time'],
                                        defRoute: i == defaultRouteIdx,
                                      ),
                                      SizedBox(
                                          height:
                                              10), // Add spacing between CircleWidgets
                                    ],
                                  ),
                              ],
                            ),
                          ] else ...[
                            CircleWidget(text1: st1, text2: t1),
                            SizedBox(height: 10),
                            CircleWidget(text1: st2, text2: t2),
                            SizedBox(height: 10),
                            CircleWidget(text1: st3, text2: t3),
                            SizedBox(height: 10),
                          ],

                          // Toggle button and Map button
                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: isExtended
                                      ? MainAxisAlignment.spaceBetween
                                      : MainAxisAlignment.end,
                                  children: [
                                    Visibility(
                                      visible: isExtended,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          GoRouter.of(context)
                                              .push("/trackingmap", extra: {
                                            'TripID': widget.TripID,
                                            'pathCoords': pathCoords,
                                            'timeList': completeInfo,
                                            'stationCoords':
                                                widget.stationCoords,
                                            'stationIds': widget.stationIds,
                                            'stationNames': widget.stationNames,
                                            'sendTimeList': sendTimeList,
                                            'sendPathCoords': sendPathCoords,
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
