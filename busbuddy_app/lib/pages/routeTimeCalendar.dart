import 'package:flutter/material.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

bool isSameDate(DateTime one, DateTime other) {
  print("hi am here");
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
  DateTime? selectedDate; // Store the selected date here
  List<String> route_ids = [], route_names = [];
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
      Fluttertoast.showToast(
          msg: 'Failed to load default route.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0);
    }
    print(r.content());

    var r1 = await Requests.post(globel.serverIp + 'getRoutes');
    r1.raiseForStatus();
    List<dynamic> json1 = r1.json();
    setState(() {
      for (int i = 0; i < json1.length; i++) {
        route_ids.add(json1[i]['id']);
        route_names.add(json1[i]['terminal_point']);
        if (json1[i]['id'] == defaultRoute) {
          selectedRouteId = route_ids[i];
          selectedRouteName = route_names[i];
        }
      }
    });
    route_names.forEach((element) {
      print(element);
    });

    var r2 = await Requests.post(globel.serverIp + 'getStations');
    r2.raiseForStatus();
    List<dynamic> json2 = r2.json();
    setState(() {
      for (int i = 0; i < json2.length; i++) {
        // List<dynamic> arr2j = json2[i]['array_to_json'];
        station_ids.add(json2[i]['id']);
        station_names.add(json2[i]['name']);
        station_coords.add(json2[i]['coords']);
        // route_st_cnt.add(arr2j.length);
      }
    });
    station_names.forEach((element) {
      print(element);
    });
    station_coords.forEach((element) {
      print(element);
    });
    context.loaderOverlay.hide();
    await onRouteSelect(defaultRoute);
    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
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
      loadedRouteTimeData = true;
    });

    print(r.content());

    // if (json['success'] == true) {
    //   setState(() {
    //     defaultRoute = json['default_route'];
    //     defaultRouteName = json['default_route_name'];
    //   });
    // } else {
    //   Fluttertoast.showToast(
    //       msg: 'Failed to load default route.',
    //       toastLength: Toast.LENGTH_SHORT,
    //       gravity: ToastGravity.CENTER,
    //       timeInSecForIosWeb: 1,
    //       backgroundColor: Colors.red,
    //       textColor: Colors.white,
    //       fontSize: 16.0);
    // }
    context.loaderOverlay.hide();
  }

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 5)),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      // Handle the selected date here, e.g., update a variable.
      setState(() {
        selectedDate = pickedDate;
      });
      rejectedData.forEach((element) {
        routeTimeData.add(element);
      });
      List<dynamic> acceptedList = [];
      routeTimeData.forEach((bus) {
        //print(bus['array_to_json'][0]['time']);
        if (isSameDate(
            DateTime.parse(bus['array_to_json'][0]['time']), selectedDate!)) {
          // print('match');
          acceptedList.add(bus);
        } else
          rejectedData.add(bus);
        routeTimeData = acceptedList;
      });
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
                        int idx = route_names.indexOf(selectedRouteName);
                        selectedRouteId = route_ids[idx];
                      });
                      onRouteSelect(selectedRouteId);
                    },
                    items: route_names
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
              // Align(
              //   alignment: Alignment.centerLeft,
              //   child: Padding(
              //     padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
              //     child: Text(
              //       'Select Bus',
              //       style: TextStyle(
              //         fontSize: 12,
              //         fontWeight: FontWeight.bold,
              //         color: Colors.grey.withOpacity(0.9),
              //       ),
              //     ),
              //   ),
              // ),

              // Container(
              //   padding: const EdgeInsets.all(8.0),
              //   decoration: BoxDecoration(
              //     borderRadius: BorderRadius.circular(10.0),
              //     border: Border.all(color: Colors.grey.withOpacity(0.5)),
              //   ),
              //   child: Padding(
              //     padding: const EdgeInsets.only(left: 10),
              //     child: DropdownButtonFormField<String>(
              //       value: selectedValue2,
              //       onChanged: (value) {},
              //       items: ['DH-0974', 'DH-0954', 'DH-0972', 'DH-0927']
              //           .map<DropdownMenuItem<String>>((String value) {
              //         return DropdownMenuItem<String>(
              //           value: value,
              //           child: Text(value),
              //         );
              //       }).toList(),
              //     ),
              //   ),
              // ),
              // SizedBox(height: 16),
              // Calendar widget code here
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
