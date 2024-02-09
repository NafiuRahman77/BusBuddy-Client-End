import 'package:flutter/material.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import 'package:google_maps_flutter/google_maps_flutter.dart';

bool isSameDate(DateTime one, DateTime other) {
  //print("hi am here");
  return one.year == other.year &&
      one.month == other.month &&
      one.day == other.day;
}

class RouteTimeCalendar extends StatefulWidget {
  @override
  _RouteTimeCalendarState createState() => _RouteTimeCalendarState();
}

class _RouteTimeCalendarState extends State<RouteTimeCalendar> {
  String selectedValue2 = 'DH-0974';
  DateTime? selectedDate = new DateTime.now(); // Store the selected date here
  List<String> station_ids = [], station_names = [];
  List<dynamic> station_coords = [];
  List<int> route_st_cnt = [];
  String defaultRoute = "";
  String defaultRouteName = "";
  String selectedRouteName = "";
  String selectedRouteId = "";
  List<dynamic> routeTimeData = [];
  List<dynamic> rejectedData = [];
  bool loadedRouteTimeData = false;
  List<dynamic> routeCoords = [];

  @override
  void initState() {
    super.initState();
    onCalendarMount();
  }

  Future<void> onCalendarMount() async {
    context.loaderOverlay.show();

    var r = await Requests.post(globel.serverIp + 'getDefaultRoute');

    r.raiseForStatus();
    dynamic json = r.json();

    if (json['success'] == true) {
      setState(() {
        defaultRoute = json['default_route'];
        defaultRouteName = json['default_route_name'];
      });
    } else {
      if (globel.userType != "student")
        defaultRoute = "4";
      else {
        Fluttertoast.showToast(
            msg: 'Failed to load default route.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Color.fromARGB(73, 77, 65, 64),
            textColor: Colors.white,
            fontSize: 16.0);
      }
    }
    //print(r.content());

    for (int i = 0; i < globel.routeIDs.length; i++) {
      if (globel.routeIDs[i] == globel.userDefaultRouteId) {
        selectedRouteId = globel.routeIDs[i];
        selectedRouteName = globel.routeNames[i];
      }
    }

    var r2 = await Requests.post(globel.serverIp + 'getStations');
    r2.raiseForStatus();
    List<dynamic> json2 = r2.json();
    setState(() {
      //clear the lists
      station_ids.clear();
      station_names.clear();
      station_coords.clear();
      for (int i = 0; i < json2.length; i++) {
        // List<dynamic> arr2j = json2[i]['array_to_json'];
        station_ids.add(json2[i]['id']);
        station_names.add(json2[i]['name']);
        station_coords.add(json2[i]['coords']);
        // route_st_cnt.add(arr2j.length);
      }
    });
    // station_names.forEach((element) {
    //   print(element);
    // });

    station_coords.forEach((element) {
      //print(element);
    });

    context.loaderOverlay.hide();
    await onRouteSelect(defaultRoute);
    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
  }

  void setDateInit() {
    List<dynamic> acceptedList = [];
    setState(() {
      rejectedData.forEach((element) {
        routeTimeData.add(element);
      });
      rejectedData.clear();
      acceptedList.clear();

      routeTimeData.forEach((bus) {
        // print(bus['array_to_json'][0]['time']);
        //print(selectedDate!);
        if (isSameDate(
            DateTime.parse(bus['array_to_json'][0]['time']), selectedDate!)) {
          //print('match');
          acceptedList.add(bus);
        } else
          rejectedData.add(bus);
      });

      routeTimeData = acceptedList;
    });

    // print("ok" + routeTimeData.length.toString());
  }

  Future<void> onRouteSelect(String route) async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getRouteTimeData',
        body: {
          'route': route,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
      routeTimeData = r.json();
      //
      //print(routeTimeData);
      loadedRouteTimeData = true;

      routeTimeData.forEach((j) {
        j["array_to_json"].forEach((stop) {
          // routeCoords.add(station_coords[int.parse(stop['station']) - 1]);
          stop['coord'] = station_coords[int.parse(stop['station']) - 1];
        });
      });

      setDateInit();
    });

    context.loaderOverlay.hide();
  }

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 5)),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      // Handle the selected date here, e.g., update a variable.
      setState(() {
        selectedDate = pickedDate;
      });
      onRouteSelect(
          globel.routeIDs[globel.routeNames.indexOf(selectedRouteName)]);
      setDateInit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
                  child: Text(
                    'Select Route',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9),
                    ),
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: DropdownButtonFormField<String>(
                    value: selectedRouteName,
                    onChanged: (value) {
                      setState(() {
                        // Handle dropdown selection
                        selectedRouteName = value!;
                        // print(selectedOption);
                        int idx = globel.routeNames.indexOf(selectedRouteName);
                        selectedRouteId = globel.routeIDs[idx];
                      });
                      onRouteSelect(selectedRouteId);
                    },
                    items: globel.routeNames
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(height: 16),
              // Choose Date dropdown
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
                  child: Text(
                    'Select Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                      ),
                      child: MaterialButton(
                        onPressed: _showDatePicker,
                        child: Text(
                          selectedDate != null
                              ? selectedDate.toString().split(' ')[0]
                              : 'Choose Date',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.7),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              if (loadedRouteTimeData)
                for (int i = 0; i < routeTimeData.length; i++)
                  // if (selectedDate == null ||
                  //     isSameDate(
                  //         DateTime.parse(
                  //             routeTimeData[i]["array_to_json"][0]['time']),
                  //         selectedDate!))
                  CustomCard(
                    title: routeTimeData[i]['bus'],
                    location1: station_names[station_ids.indexOf(
                        routeTimeData[i]["array_to_json"][0]['station'])],
                    time1: DateFormat('jm').format(DateTime.parse(
                            routeTimeData[i]["array_to_json"][0]['time'])
                        .toLocal()),
                    location2: station_names[station_ids.indexOf(
                        routeTimeData[i]["array_to_json"]
                                [routeTimeData[i]["array_to_json"].length - 3]
                            ['station'])],
                    time2: DateFormat('jm').format(DateTime.parse(routeTimeData[
                                    i]["array_to_json"]
                                [routeTimeData[i]["array_to_json"].length - 3]
                            ['time'])
                        .toLocal()),
                    location3: station_names[station_ids.indexOf(
                        routeTimeData[i]["array_to_json"]
                                [routeTimeData[i]["array_to_json"].length - 1]
                            ['station'])],
                    time3: DateFormat('jm').format(DateTime.parse(routeTimeData[
                                    i]["array_to_json"]
                                [routeTimeData[i]["array_to_json"].length - 1]
                            ['time'])
                        .toLocal()),
                    extendedInfo: routeTimeData[i]["array_to_json"],
                    stationIds: station_ids,
                    stationNames: station_names,
                    stationCoords: station_coords,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
