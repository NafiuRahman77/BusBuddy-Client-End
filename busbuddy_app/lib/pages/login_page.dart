import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'show_profile.dart';
import '../components/my_button.dart';
import 'package:go_router/go_router.dart';
import '../components/my_textfield.dart';
import '../components/square_tile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool hidepass = true;
  // text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> startLocationStream() async {
    late LocationSettings locationSettings;

    locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: globel.distanceFilter,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 10),
        //(Optional) Set foreground notification config to keep the app alive
        //when going to the background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "BusBuddy app will continue to receive your location even when you aren't using it",
          notificationTitle: "Running in Background",
          enableWakeLock: true,
        ));

    globel.positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position? position) async {
      print(position == null
          ? 'Unknown'
          : '${position.latitude.toString()}, ${position.longitude.toString()}');

      if (position != null) {
        var r2 = await Requests.post(globel.serverIp + 'updateStaffLocation',
            body: {
              'trip_id': globel.runningTripId,
              'latitude': position.latitude.toString(),
              'longitude': position.longitude.toString(),
            },
            bodyEncoding: RequestBodyEncoding.FormURLEncoded);

        r2.raiseForStatus();
      }
    });
  }

  bool isConnected = true;
  bool flagforofflinebutton = false;
  bool loaderShowing = false;
  bool netChecked = false;

  @override
  void initState() {
    super.initState();
    onLoginMount();
  }

  Future<void> onLoginMount() async {
    print('Checking internet connection... 1');
    bool result = await InternetConnectionChecker().hasConnection;
    final SharedPreferences prefs1 = await SharedPreferences.getInstance();
    List<String> ticketIds = prefs1.getStringList('ticketIds') ?? [];
    print("connected: $result");

    context.loaderOverlay.show();
    loaderShowing = true;
    setState(() {
      if (result == true) {
        isConnected = true;
      } else {
        print('No internet :( Reason:');
        Fluttertoast.showToast(
            msg:
                'No internet connection. Please connect to the internet and try again.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Color.fromARGB(131, 244, 67, 54),
            textColor: Colors.white,
            fontSize: 16.0);
        isConnected = false;
      }
      flagforofflinebutton = ticketIds.isNotEmpty;
    });
    netChecked = true;
    if (!isConnected) {
      context.loaderOverlay.hide();
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? c = await prefs.getString('connect.sid');
    if (c != null) {
      await Requests.addCookie(
          Requests.getHostname(globel.serverIp), 'connect.sid', c);

      // context.loaderOverlay.show();
      var r = await Requests.post(globel.serverIp + 'sessionCheck',
          body: {
            'fcm_id': globel.fcmId,
          },
          bodyEncoding: RequestBodyEncoding.FormURLEncoded);

      r.raiseForStatus();
      dynamic json = r.json();
      print(json);
      if (json['recognized'] == true) {
        globel.userType = json['user_type'];

        // if (isConnected == true) {
        globel.routeIDs.clear();
        globel.routeNames.clear();
        var r1 = await Requests.post(globel.serverIp + 'getRoutes');
        r1.raiseForStatus();
        List<dynamic> json1 = r1.json();
        setState(() {
          for (int i = 0; i < json1.length; i++) {
            globel.routeIDs.add(json1[i]['id']);
            globel.routeNames.add(json1[i]['terminal_point']);
          }
        });

        print(globel.routeNames);
        // }

        if (globel.userType == 'bus_staff') {
          globel.staffRole = json['bus_role'];
          if (json['relogin'] == true) {
            Fluttertoast.showToast(
                msg:
                    'Bus staff can login from only one device at once. Your previous sessions have been deactivated',
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Color.fromARGB(131, 244, 67, 54),
                textColor: Colors.white,
                fontSize: 16.0);
          }

          var r4 =
              await Requests.post(globel.serverIp + 'checkStaffRunningTrip');
          print("hello bus stff");
          r4.raiseForStatus();
          dynamic rt = r4.json();
          if (rt['success']) {
            globel.runningTripId = rt['id'];
            if (globel.staffRole == 'driver') {
              bool isLocationServiceEnabled =
                  await Geolocator.isLocationServiceEnabled();

              // Workmanager()
              //     .registerOneOffTask("bus", "sojib")
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
                SystemNavigator.pop();
              }

              // Check if the app has location permission
              LocationPermission permission =
                  await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                // Request location permission
                permission = await Geolocator.requestPermission();
                if (permission != LocationPermission.whileInUse &&
                    permission != LocationPermission.always) {
                  // Handle the case where the user denied location permission
                  print('User denied location permission.');
                  SystemNavigator.pop();
                }
              }
              try {
                await startLocationStream();
                // return true;
              } catch (e) {
                print("Error getting location: $e");
                SystemNavigator.pop();
              }
            }
          }
        }
        if (globel.userType == 'student') {
          // context.loaderOverlay.show();
          var r = await Requests.post(globel.serverIp + 'getTicketList');

          r.raiseForStatus();
          dynamic json = r.json();
          print(json);

          if (json['success'] == true) {
            List<String> ticketIds = List<String>.from(json['ticket_list']);

            final SharedPreferences prefs =
                await SharedPreferences.getInstance();
            prefs.setStringList('ticketIds', ticketIds);
            // setState(() {
            //   flagforofflinebutton = ticketIds.isNotEmpty;
            // });
            print(ticketIds.isNotEmpty.toString() + "..........");
          } else {
            // Fluttertoast.showToast(
            //   msg: 'Failed to load data.',
            //   toastLength: Toast.LENGTH_SHORT,
            //   gravity: ToastGravity.CENTER,
            //   timeInSecForIosWeb: 1,
            //   backgroundColor: Color.fromARGB(118, 244, 67, 54),
            //   textColor: Colors.white,
            //   fontSize: 16.0,
            // );
          }
          // context.loaderOverlay.hide();
        }
        await onProfileReady();
        await onProfileMount();

        loaderShowing = false;
        context.loaderOverlay.hide();
        GoRouter.of(context).go("/show_profile");
      }
    }
    if (loaderShowing == true) {
      context.loaderOverlay.hide();
    }
  }

  Future<bool> onLogin(String id, String password) async {
    print('Checking internet connection... 2');
    var r = await Requests.post(globel.serverIp + 'login',
        body: {
          'id': id,
          'password': password,
          'fcm_id': globel.fcmId,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    print(json['success']);

    if (json['success'] == true) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String pref_id = prefs.getString("student_id") ?? "";
      if (pref_id != "") {
        if (id != pref_id) {
          prefs.setStringList('noti_title', []);
          prefs.setStringList('noti_body', []);
          prefs.setStringList("noti_time", []);
        }
      }
      // set student id to shared pref
      prefs.setString('student_id', id);
      print("..........");
      CookieJar cj = await Requests.getStoredCookies(
          Requests.getHostname(globel.serverIp));
      cj.forEach((key, value) async {
        print(key);
        print(value);
        await (prefs.setString(key, value.value));
      });
      globel.userType = json['user_type'];

      // if (isConnected == true) {
      globel.routeIDs.clear();
      globel.routeNames.clear();
      var r1 = await Requests.post(globel.serverIp + 'getRoutes');
      r1.raiseForStatus();
      List<dynamic> json1 = r1.json();
      setState(() {
        for (int i = 0; i < json1.length; i++) {
          globel.routeIDs.add(json1[i]['id']);
          globel.routeNames.add(json1[i]['terminal_point']);
        }
      });

      print(globel.routeNames);
      // }

      if (globel.userType == 'bus_staff') {
        globel.staffRole = json['bus_role'];
        if (json['relogin'] == true) {
          Fluttertoast.showToast(
              msg:
                  'Bus staff can login from only one device at once. Your previous sessions have been deactivated',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
              backgroundColor: Color.fromARGB(131, 244, 67, 54),
              textColor: Colors.white,
              fontSize: 16.0);
        }

        var r4 = await Requests.post(globel.serverIp + 'checkStaffRunningTrip');
        print("hello bus stff");
        r4.raiseForStatus();
        dynamic rt = r4.json();
        if (rt['success']) {
          globel.runningTripId = rt['id'];
          if (globel.staffRole == 'driver') {
            bool isLocationServiceEnabled =
                await Geolocator.isLocationServiceEnabled();

            // Workmanager()
            //     .registerOneOffTask("bus", "sojib")
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
              await startLocationStream();
              return true;
            } catch (e) {
              print("Error getting location: $e");
              return false;
            }
          }
        }
      }
      if (globel.userType == 'student') {
        // context.loaderOverlay.show();
        var r = await Requests.post(globel.serverIp + 'getTicketList');

        r.raiseForStatus();
        dynamic json = r.json();
        print(json);

        if (json['success'] == true) {
          List<String> ticketIds = List<String>.from(json['ticket_list']);

          final SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setStringList('ticketIds', ticketIds);
          // setState(() {
          //   flagforofflinebutton = ticketIds.isNotEmpty;
          // });
          print(ticketIds.isNotEmpty.toString() + "..........");
        } else {
          // Fluttertoast.showToast(
          //   msg: 'Failed to load data.',
          //   toastLength: Toast.LENGTH_SHORT,
          //   gravity: ToastGravity.CENTER,
          //   timeInSecForIosWeb: 1,
          //   backgroundColor: Color.fromARGB(118, 244, 67, 54),
          //   textColor: Colors.white,
          //   fontSize: 16.0,
          // );
        }
        // context.loaderOverlay.hide();
      }
      // print(globel.userType);
      Fluttertoast.showToast(
          msg: 'Welcome, ${json['name']}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 56, 52, 52),
          textColor: Colors.white,
          fontSize: 16.0);

      return true;
    } else {
      Fluttertoast.showToast(
          msg: 'Invalid credentiels',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(131, 244, 67, 54),
          textColor: Colors.white,
          fontSize: 16.0);
    }

    return false;
  }
  // sign user in method

  Future<void> onProfileReady() async {
    print('Checking internet connection... 3');
    var r = await Requests.post(globel.serverIp + 'getProfileStatic');

    r.raiseForStatus();
    dynamic json = r.json();

    print(r.content());
    if (json['success'] == true) {
      globel.userName = json['name'];
      if (json['imageStr'].toString().isNotEmpty) {
        globel.userAvatar = MemoryImage(base64Decode(json['imageStr']));
      }
    } else {
      Fluttertoast.showToast(
          msg: 'Failed to load data.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(147, 210, 61, 50),
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  Future<void> onProfileMount() async {
    var r = await Requests.post(globel.serverIp + 'getProfile');

    r.raiseForStatus();
    dynamic json = r.json();

    print(r.content());

    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
    if (json['success'] == true) {
      setState(() {
        globel.userName = json['name'];
        globel.userPhone = json['phone'];
        if (globel.userType == "student") {
          globel.userEmail = json['email'];
          globel.userDefaultRouteId = json['default_route'];
          globel.userDefaultRouteName = json['default_route_name'];
          globel.userDefaultStationId = json['default_station'];
          globel.userDefaultStationName = json['default_station_name'];
        } else if (globel.userType == "buet_staff") {
          globel.teacherDepartment = json['department'];
          globel.teacherDesignation = json['designation'];
          globel.teacherResidence = json['residence'];
        } else if (globel.userType == "bus_staff") {
          globel.staffRole = json['role'];
        }

        globel.userId = json['id'];
      });
    } else {
      Fluttertoast.showToast(
          msg: 'Failed to load data.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(148, 244, 67, 54),
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: Color.fromARGB(150, 200, 200, 200),
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 21, 21, 21),
        body: SingleChildScrollView(
          // Add this line
          child: Container(
            height: MediaQuery.of(context).size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEB2A2A), Color.fromARGB(255, 21, 21, 21)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 50),
                    Image(
                      width: 300,
                      image: AssetImage('lib/images/logobusbuddy-1.png'),
                    ),
                    Text(
                      'BusBuddy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 25),
                    const SizedBox(height: 50),

                    Visibility(
                      visible: netChecked && isConnected,
                      child: Column(
                        children: [
                          // username textfield

                          MyTextField(
                            controller: usernameController,
                            hintText: 'Username',
                            obscureText: false,
                            ispass: false,
                          ),
                          const SizedBox(height: 50),
                          // password textfield
                          MyTextField(
                            controller: passwordController,
                            hintText: 'Password',
                            obscureText: hidepass,
                            ispass: true,
                          ),
                          const SizedBox(height: 50),
                          // sign in button
                          MyButton(
                            onTap: () async {
                              context.loaderOverlay.show();
                              bool lgin = await onLogin(usernameController.text,
                                  passwordController.text);
                              if (lgin == true) {
                                await onProfileReady();
                                await onProfileMount();
                                context.loaderOverlay.hide();
                                GoRouter.of(context).go("/show_profile");
                              } else {
                                context.loaderOverlay.hide();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: netChecked && !isConnected,
                      child: Column(
                        children: [
                          const SizedBox(height: 70),
                          ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.white.withOpacity(0.6),
                              BlendMode.srcIn,
                            ),
                            child: IconButton(
                              onPressed: () {
                                print("retry");
                                onLoginMount();
                              },
                              icon: Icon(Icons.refresh, size: 50),
                              tooltip: 'Retry',
                            ),
                          ),
                          const SizedBox(height: 20),
                          Visibility(
                            visible: netChecked && flagforofflinebutton,
                            child: ElevatedButton(
                              onPressed: () {
                                GoRouter.of(context).push("/offline_ticket");
                              },
                              child: Text("Offline Ticket"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 70),
                    // forgot password?
                    Visibility(
                      visible: netChecked && isConnected,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
