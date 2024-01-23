import 'dart:convert';
import 'dart:ffi';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:flutter/material.dart';
import '../components/my_textfield.dart';
import '../components/CustomAppBar.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:go_router/go_router.dart';
import '../../globel.dart' as globel;

class Route {
  const Route(this.id, this.name);
  final String name;
  final String id;
}

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  TextEditingController routeController = TextEditingController();
  TextEditingController phoneNoController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  String defaultRoute = "";
  String defaultStation = "";
  String defaultRouteName = "";
  String email = "";
  String phoneNo = "";
  String id = "";
  List<String> route_ids = [];
  List<String> route_names = [];
  List<String> station_ids = [];
  List<String> station_names = [];
  String selectedOption = "";
  String selectedId = "";
  String selectedStationOption = "";
  String selectedStationId = "";
  @override
  void initState() {
    super.initState();
    onProfileMount();
  }

  Future<void> onRouteSelect(String route) async {
    context.loaderOverlay.show();
    var r2 = await Requests.post(globel.serverIp + 'getRouteStations',
        body: {
          'route': route,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r2.raiseForStatus();

    List<dynamic> json2 = r2.json();
    //print(json2);
    setState(() {
      for (int i = 0; i < json2.length; i++) {
        station_ids.add(json2[i]['id']);
        station_names.add(json2[i]['name']);
        if (json2[i]['id'] == defaultStation) {
          selectedStationId = station_ids[i];
          selectedStationOption = station_names[i];
        }
      }
    });
    context.loaderOverlay.hide();
  }

  Future<void> onProfileMount() async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getProfile');

    r.raiseForStatus();
    dynamic json = r.json();
    //print(r.content());

    if (json['success'] == true) {
      setState(() {
        email = json['email'];
        phoneNo = json['phone'];
        defaultRoute = json['default_route'];
        defaultRouteName = json['default_route_name'];
        defaultStation = json['default_station'];
        id = json['id'].toString().trim();
      });
    } else {
      Fluttertoast.showToast(
          msg: 'Failed to load data.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(136, 244, 67, 54),
          textColor: Colors.white,
          fontSize: 16.0);
    }
    //print(r.content());
    var r1 = await Requests.post(globel.serverIp + 'getRoutes');

    r1.raiseForStatus();
    List<dynamic> json1 = r1.json();
    // print(r1.content());
    // json1.forEach((element) {
    //   routes.add(new Route(element['id'], element['terminal_point']));
    // });
    setState(() {
      for (int i = 0; i < json1.length; i++) {
        route_ids.add(json1[i]['id']);
        route_names.add(json1[i]['terminal_point']);
        if (json1[i]['id'] == defaultRoute) {
          selectedId = route_ids[i];
          selectedOption = route_names[i];
        }
      }
    });

    // route_names.forEach((element) {
    //   print(element);
    // });

    //print(r.content());
    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
    context.loaderOverlay.hide();
    onRouteSelect(defaultRoute);
  }

  Future<void> editProfile(
      String def_route, String mail, String phn_no, String stn) async {
    context.loaderOverlay.show();
    print("hello");
    if (def_route.isEmpty) def_route = defaultRoute;
    if (stn.isEmpty) stn = defaultStation;
    if (mail.isEmpty) mail = email;
    if (phn_no.isEmpty) phn_no = phoneNo;
    var r = await Requests.post(globel.serverIp + 'updateProfile',
        body: {
          'phone': phn_no,
          'email': mail,
          'default_route': def_route,
          'default_station': stn,
          'id': id,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    print(r.content());

    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
    if (json['success'] == true) {
      Fluttertoast.showToast(
          msg: 'Saved changes successfully.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(131, 71, 62, 62),
          textColor: Colors.white,
          fontSize: 16.0);
    } else {
      Fluttertoast.showToast(
          msg: 'Failed to load data.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(97, 212, 33, 21),
          textColor: Colors.white,
          fontSize: 16.0);
    }
    globel.userEmail = mail;
    globel.userPhone = phn_no;
    globel.userDefaultRouteId = def_route;
    globel.userDefaultStationId = stn;
    globel.userDefaultRouteName = route_names[route_ids.indexOf(def_route)];
    globel.userDefaultStationName = station_names[station_ids.indexOf(stn)];
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildProfilePicture(),
              SizedBox(height: 16.0),
              CustomInputWidget(
                controller: emailController,
                hintText: email,
                heading: 'Email',
              ),
              SizedBox(height: 16.0),
              CustomInputWidget(
                controller: phoneNoController,
                hintText: phoneNo,
                heading: 'Phone no.',
              ),
              SizedBox(height: 16.0),
              Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  "Default route",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9)),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Color.fromARGB(255, 236, 237, 237)),
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 252, 252, 252)
                          .withOpacity(0.5), // Shadow color
                      spreadRadius: 5, // Spread radius
                      blurRadius: 7, // Blur radius
                      offset: Offset(0, 3), // Offset
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: DropdownButtonFormField<String>(
                    value: selectedOption,
                    onChanged: (value) async {
                      setState(() {
                        selectedOption = value!;
                        // print(selectedOption);
                        int idx = route_names.indexOf(selectedOption);
                        selectedId = route_ids[idx];
                        station_ids.clear();
                        station_names.clear();
                      });
                      // Handle dropdown selection
                      await onRouteSelect(selectedId);
                      setState(() {
                        selectedStationId = station_ids[0];
                        selectedStationOption = station_names[0];
                      });
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
              SizedBox(height: 16.0),
              Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Text(
                  "Default station",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9)),
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Color.fromARGB(255, 236, 237, 237)),
                  borderRadius: BorderRadius.circular(10.0),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 252, 252, 252)
                          .withOpacity(0.5), // Shadow color
                      spreadRadius: 5, // Spread radius
                      blurRadius: 7, // Blur radius
                      offset: Offset(0, 3), // Offset
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 0),
                  child: DropdownButtonFormField<String>(
                    value: selectedStationOption,
                    onChanged: (value) {
                      // Handle dropdown selection
                      setState(() {
                        selectedStationOption = value!;
                        // print(selectedOption);
                        int idx = station_names.indexOf(selectedStationOption);
                        selectedStationId = station_ids[idx];
                      });
                    },
                    items: station_names
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // Handle saving changes here
                    // You can access the entered values using the controller.text
                    // For example, nameController.text will give you the name entered by the user
                    await editProfile(selectedId, emailController.text,
                        phoneNoController.text, selectedStationId);
                    GoRouter.of(context).replace("/show_profile");
                    // GoRouter.of(context).refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(
                          0.8), // Set the text color to white or your desired color
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildProfilePicture() {
  return Center(
    child: CircleAvatar(
      radius: 144 / 2,
      backgroundColor: Colors.white,
      backgroundImage: globel.userAvatar,
    ),
  );
}

class CustomInputWidget extends StatelessWidget {
  final String heading;
  final String hintText;
  final TextEditingController controller;

  const CustomInputWidget({
    Key? key,
    required this.heading,
    required this.hintText,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            heading,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.withOpacity(0.9)),
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.black
                      .withOpacity(0.3), // Set opacity value as needed
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
