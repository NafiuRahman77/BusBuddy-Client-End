import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:busbuddy_app/pages/edit_password.dart';
import 'package:busbuddy_app/pages/offline_ticket.dart';
import 'package:busbuddy_app/pages/scan_ticket_qr.dart';
import 'package:busbuddy_app/pages/ticket_qr.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:path_provider/path_provider.dart';
import 'pages/tracking.dart';
import 'pages/trackingMap.dart';
import 'pages/ticket_choose.dart';
import 'pages/ticket_history.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/add_feedback.dart';
import 'pages/edit_profile.dart';
import 'pages/show_profile.dart';
import 'pages/login_page.dart';
import 'pages/routeTimeCalendar.dart';
import 'pages/route_map.dart';
import 'pages/Requisition.dart';
import 'package:shurjopay/utilities/functions.dart';
import 'pages/ShowFeedback.dart';
import 'pages/show_notifications.dart';
import 'pages/manage_trips.dart';
import 'pages/req_and_repair.dart';
import 'pages/ShowRequisition.dart';
import 'package:requests/requests.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'globel.dart' as globel;

// @pragma('vm:entry-point')
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma(
    'vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void main() async {
  initializeShurjopay(environment: "sandbox");
  Requests.setStoredCookies(globel.serverAddr, globel.cookieJar);
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'busbuddy_broadcast',
    'Notice Broadcasts',
    description: 'Receive regular announcements and updates.',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.instance.getToken().then((value) {
    print("token: $value");
    if (value != null) {
      globel.fcmId = value;
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("received fcm: ${message.data}");
    if (message.notification != null) {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails('busbuddy_broadcast', 'Notice Broadcasts',
              channelDescription: 'Receive regular announcements and updates.',
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker');
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidNotificationDetails);
      await flutterLocalNotificationsPlugin.show(0, message.notification?.title,
          message.notification?.body, notificationDetails,
          payload: 'item x');

      //save message.notification?.title, message.notification?.body to shared preferences as an array
      var prefs = await SharedPreferences.getInstance();
      // print message.notification?.title and message.notification?.body
      print(message.notification?.title);
      print(message.notification?.body);
      List<String> noti_title = prefs.getStringList('noti_title') ?? [];
      List<String> noti_body = prefs.getStringList('noti_body') ?? [];
      noti_title.add(message.notification?.title ?? "");
      noti_body.add(message.notification?.body ?? "");
      prefs.setStringList('noti_title', noti_title);
      prefs.setStringList('noti_body', noti_body);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print("openedAppreceived fcm: ${message.data}");
    var prefs = await SharedPreferences.getInstance();
    print(message.notification?.title);
    print(message.notification?.body);
    List<String> noti_title = prefs.getStringList('noti_title') ?? [];
    List<String> noti_body = prefs.getStringList('noti_body') ?? [];
    noti_title.add(message.notification?.title ?? "");
    noti_body.add(message.notification?.body ?? "");
    prefs.setStringList('noti_title', noti_title);
    prefs.setStringList('noti_body', noti_body);
  });

  FirebaseMessaging.instance
      .getInitialMessage()
      .then((RemoteMessage? message) async {
    if (message != null) {
      print("hiii woke up from bg");

      print(message.data);
      var prefs = await SharedPreferences.getInstance();
      print(message.notification?.title);
      print(message.notification?.body);
      List<String> noti_title = prefs.getStringList('noti_title') ?? [];
      List<String> noti_body = prefs.getStringList('noti_body') ?? [];
      noti_title.add(message.notification?.title ?? "");
      noti_body.add(message.notification?.body ?? "");
      prefs.setStringList('noti_title', noti_title);
      prefs.setStringList('noti_body', noti_body);
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(BusBuddyApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print("bg message handler");
  var prefs = await SharedPreferences.getInstance();
  print(message.notification?.title);
  print(message.notification?.body);
  List<String> noti_title = prefs.getStringList('noti_title') ?? [];
  List<String> noti_body = prefs.getStringList('noti_body') ?? [];
  noti_title.add(message.notification?.title ?? "");
  noti_body.add(message.notification?.body ?? "");
  prefs.setStringList('noti_title', noti_title);
  prefs.setStringList('noti_body', noti_body);
  // runApp(BusBuddyApp());
  // main();
  // if (message.notification != null) {
  //   const AndroidNotificationDetails androidNotificationDetails =
  //       AndroidNotificationDetails('busbuddy_broadcast', 'Broadcast Notices',
  //           channelDescription: 'Receive regular announcements and updates.',
  //           importance: Importance.max,
  //           priority: Priority.high,
  //           ticker: 'ticker');
  //   const NotificationDetails notificationDetails =
  //       NotificationDetails(android: androidNotificationDetails);
  //   await flutterLocalNotificationsPlugin.show(0, message.notification?.title,
  //       message.notification?.body, notificationDetails,
  //       payload: 'item x');
  // }
}

class BusBuddyApp extends StatelessWidget {
  BusBuddyApp({super.key});
  final GoRouter router = GoRouter(initialLocation: "/login", routes: [
    GoRoute(
        path: "/user_feedback",
        builder: ((context, state) => const HomeView(page: "User Feedback"))),
    GoRoute(
        path: "/show_profile",
        builder: ((context, state) => const HomeView(page: "Show Profile"))),
    GoRoute(
        path: "/edit_profile",
        builder: ((context, state) => const HomeView(page: "Edit Profile"))),
    GoRoute(path: "/login", builder: ((context, state) => const LoginPage())),
    GoRoute(
        path: "/ticket_choose",
        builder: ((context, state) => const HomeView(page: "Choose Ticket"))),
    GoRoute(
        path: "/ticket_history",
        builder: ((context, state) => const HomeView(page: "Ticket History"))),
    GoRoute(
        path: "/confirm_payment",
        builder: ((context, state) => const HomeView(page: "Confirm Payment"))),
    GoRoute(
        path: "/route_calendar",
        builder: ((context, state) => HomeView(page: "Route Calendar"))),
    GoRoute(
        path: "/routetimemap",
        builder: ((context, state) =>
            HomeView(page: "Route Map", extra: state.extra))),
    GoRoute(
        path: "/user_requisition",
        builder: ((context, state) =>
            const HomeView(page: "User Requisition"))),
    GoRoute(
        path: "/prev_feedback",
        builder: ((context, state) =>
            const HomeView(page: "Feedback Response"))),
    GoRoute(
        path: "/show_requisition",
        builder: ((context, state) =>
            const HomeView(page: "Show Requisition"))),
    GoRoute(
        path: "/qr_code",
        builder: ((context, state) => const HomeView(page: "QR Code"))),
    GoRoute(
        path: "/scan_qr_code",
        builder: ((context, state) => const HomeView(page: "Scan QR Code"))),
    GoRoute(
        path: "/manage_trips",
        builder: ((context, state) => const HomeView(page: "Manage Trips"))),
    GoRoute(
        path: "/req_repair",
        builder: ((context, state) => const HomeView(page: "Request Repair"))),
    GoRoute(
        path: "/tracking",
        builder: ((context, state) => const HomeView(page: "Tracking"))),
    GoRoute(
        path: "/trackingmap",
        builder: ((context, state) =>
            HomeView(page: "Tracking Map", extra: state.extra))),
    GoRoute(
        path: "/notifications",
        builder: ((context, state) => const HomeView(page: "Notifications"))),
    GoRoute(
        path: "/edit_password",
        builder: ((context, state) => const HomeView(page: "Edit Password"))),
    GoRoute(
        path: "/offline_ticket",
        builder: ((context, state) => OfflineTicketQR()))
  ]);
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BusBuddy',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF781B1B), brightness: Brightness.light),
        useMaterial3: true,
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  PageBody({required this.page, this.extra});
  String page;
  Object? extra;
  @override
  Widget build(BuildContext context) {
    if (this.page == "User Feedback")
      return FeedbackForm();
    else if (this.page == "Show Profile")
      return ShowProfile();
    else if (this.page == "Edit Profile")
      return EditProfileScreen();
    else if (this.page == "Choose Ticket")
      return TicketChoose();
    else if (this.page == "Ticket History")
      return TicketHistory();
    else if (this.page == "Route Calendar")
      return RouteTimeCalendar();
    else if (this.page == "Route Map")
      return RouteTimeMap(
        stationPoints: this.extra! as Set<Marker>,
      );
    else if (this.page == "User Requisition")
      return Requisition();
    else if (this.page == "Feedback Response")
      return ShowFeedback();
    else if (this.page == "Show Requisition")
      return ShowRequisition();
    else if (this.page == "QR Code")
      return TicketQR();
    else if (this.page == "Scan QR Code")
      return ScanTicketQR();
    else if (this.page == "Manage Trips")
      return ManageTrips();
    else if (this.page == "Request Repair")
      return ReqRepair();
    else if (this.page == "Tracking")
      return Tracking();
    else if (this.page == "Notifications")
      return Notifications();
    else if (this.page == "Tracking Map")
      return trackingMap(
        extra: this.extra! as dynamic,
        // pathCoords: this.extra! as List<dynamic>,
      );
    else if (this.page == "Edit Password") {
      return EditPasswordPage();
    } else if (this.page == "Offline QR") {
      return OfflineTicketQR();
    } else
      return (Container());
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.page, this.extra});
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String page;
  final Object? extra;

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  int? _selectedIndex;
  String? currentRouteName;

  int exp1 = 0;
  int exp2 = 0;
  int exp3 = 0;

  @override
  void initState() {
    super.initState();

    _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    currentRouteName = ModalRoute.of(context)?.settings.name;

    // Now you can use currentRouteName to check the route name
    if (currentRouteName == '/show_profile') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 0;
    } else if (currentRouteName == '/ticket_choose') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 1;
    } else if (currentRouteName == '/ticket_history') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 2;
    } else if (currentRouteName == '/route_calendar') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 3;
    } else if (currentRouteName == '/tracking') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 4;
    } else if (currentRouteName == '/user_feedback') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 5;
    } else if (currentRouteName == '/prev_feedback') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 6;
    } else if (currentRouteName == '/user_requisition') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 7;
    } else if (currentRouteName == '/show_requisition') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 8;
    } else if (currentRouteName == '/notifications') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 9;
    } else if (currentRouteName == '/qr_code') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 10;
    } else if (currentRouteName == '/scan_qr_code') {
      // You are currently on the '/your_route_name' route
      _selectedIndex = 13;
    } else if (currentRouteName == '/manage_trips') {
      _selectedIndex = 14;
    } else if (currentRouteName == '/req_repair') {
      _selectedIndex = 15;
    } else if (currentRouteName == '/route_map') {
      print("route map");
      _selectedIndex = 3;
    } else if (currentRouteName == '/edit_password') {
      _selectedIndex = 16;
    } else if (currentRouteName == '/offline_ticket') {
      _selectedIndex = 17;
    } else {
      _selectedIndex = 1000;
    }
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return LoaderOverlay(
      overlayColor: Color.fromARGB(150, 200, 200, 200),
      child: Scaffold(
        appBar: AppBar(
          // TRY THIS: Try changing the color here to a specific color (to
          // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
          // change color while the other colors stay the same.
          backgroundColor: Color(0xFF781B1B),
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          foregroundColor: Colors.white,
          title: Text(widget.page),
        ),
        body: PageBody(page: widget.page, extra: widget.extra),
        drawer: SafeArea(
          child: Container(
            padding: EdgeInsets.all(0),
            width: 250,
            child: Drawer(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                child: ListView(
                  // Important: Remove any padding from the ListView.
                  children: <Widget>[
                    Column(
                      // Important: Remove any padding from the ListView.
                      children: <Widget>[
                        DrawerHeader(
                          padding: EdgeInsets.zero,
                          child: UserAccountsDrawerHeader(
                            accountName: Text(
                              globel.userName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                              ),
                            ),
                            accountEmail:
                                null, // If you don't want to display an email, set it to null
                            currentAccountPicture: CircleAvatar(
                              radius: 48 / 2,
                              backgroundColor: Colors.white,
                              backgroundImage: globel.userAvatar,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF781B1B),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.account_box),
                          title: const Text('Profile'),
                          selected: _selectedIndex == 0,
                          onTap: () {
                            // Update the state of the app
                            if (_selectedIndex == 0) return;
                            GoRouter.of(context).pop();
                            GoRouter.of(context).push("/show_profile");
                            setState(() {
                              _selectedIndex = 0;
                            });

                            // Then close the drawer
                          },
                        ),
                        if (globel.userType == "student")
                          ExpansionTile(
                            initiallyExpanded:
                                (_selectedIndex == 1 || _selectedIndex == 2),
                            leading: Icon(
                              Icons.confirmation_num,
                              color: Colors.black,
                            ), // Change color based on the selected index,),
                            title: Text(
                              'Tickets',
                              style: TextStyle(
                                color: Colors
                                    .black, // Change color based on the selected index
                              ),
                            ),
                            onExpansionChanged: (bool expanded) {
                              if (expanded) {
                                // The tile is expanded, update the selected index or perform other actions.
                                setState(() {
                                  _selectedIndex = 1;
                                  exp1 = 1;
                                });
                              } else {
                                setState(() {
                                  _selectedIndex = 1;
                                  exp1 = 0;
                                });
                              }
                            },
                            children: <Widget>[
                              ListTile(
                                leading: Icon(Icons.money),
                                title: Text('Buy Ticket'),
                                selected: _selectedIndex == 1,
                                onTap: () {
                                  GoRouter.of(context).pop();
                                  GoRouter.of(context).push("/ticket_choose");
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.history),
                                title: Text('Ticket History'),
                                selected: _selectedIndex == 2,
                                onTap: () {
                                  GoRouter.of(context).pop();
                                  GoRouter.of(context).push("/ticket_history");
                                },
                              ),
                            ],
                          ),
                        if (globel.userType != "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: const Text('Calendar'),
                            selected: _selectedIndex == 3,
                            onTap: () {
                              // Update the state of the app
                              // _onItemTapped(2);
                              if (_selectedIndex == 3) return;
                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/route_calendar");
                              setState(() {
                                _selectedIndex = 3;
                              });
                              // Then close the drawer
                            },
                          ),
                        if (globel.userType != "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.place),
                            title: const Text('Tracking'),
                            selected: _selectedIndex == 4,
                            onTap: () {
                              if (_selectedIndex == 4) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer
                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/tracking");
                              setState(() {
                                _selectedIndex = 4;
                              });
                            },
                          ),
                        if (globel.userType != "bus_staff")
                          ExpansionTile(
                              initiallyExpanded:
                                  (_selectedIndex == 5 || _selectedIndex == 6),
                              leading: Icon(
                                Icons.feedback,
                                color: Colors.black,
                              ), // Change color based on the selected index,),
                              title: Text(
                                'Feedback',
                                style: TextStyle(
                                  color: Colors
                                      .black, // Change color based on the selected index
                                ),
                              ),
                              onExpansionChanged: (bool expanded) {
                                if (expanded) {
                                  // The tile is expanded, update the selected index or perform other actions.
                                  setState(() {
                                    _selectedIndex = 5;
                                    exp2 = 1;
                                  });
                                } else {
                                  setState(() {
                                    _selectedIndex = 5;
                                    exp2 = 0;
                                  });
                                }
                              },
                              children: <Widget>[
                                ListTile(
                                  leading: const Icon(Icons.post_add),
                                  title: const Text('Submit Feedback'),
                                  selected: _selectedIndex == 5,
                                  onTap: () {
                                    if (_selectedIndex == 5) return;
                                    // Update the state of the app
                                    GoRouter.of(context).pop();
                                    GoRouter.of(context).push("/user_feedback");
                                    setState(() {
                                      _selectedIndex = 5;
                                    });
                                    // Then close the drawer
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.history),
                                  title: const Text('Feedback History'),
                                  selected: _selectedIndex == 6,
                                  onTap: () {
                                    if (_selectedIndex == 6) return;
                                    // Update the state of the app
                                    GoRouter.of(context).pop();
                                    GoRouter.of(context).push("/prev_feedback");
                                    setState(() {
                                      _selectedIndex = 6;
                                    });
                                    // Then close the drawer
                                  },
                                ),
                              ]),
                        if (globel.userType == "buet_staff")
                          ExpansionTile(
                              initiallyExpanded:
                                  (_selectedIndex == 7 || _selectedIndex == 8),
                              leading: Icon(
                                Icons.bus_alert,
                                color: Colors.black,
                              ), // Change color based on the selected index,),
                              title: Text(
                                'Requisition',
                                style: TextStyle(
                                  color: Colors
                                      .black, // Change color based on the selected index
                                ),
                              ),
                              onExpansionChanged: (bool expanded) {
                                if (expanded) {
                                  // The tile is expanded, update the selected ind ex or perform other actions.
                                  setState(() {
                                    _selectedIndex = 7;
                                    exp3 = 1;
                                  });
                                } else {
                                  setState(() {
                                    _selectedIndex = 7;
                                    exp3 = 0;
                                  });
                                }
                              },
                              children: <Widget>[
                                ListTile(
                                  //show_requisition
                                  leading: const Icon(Icons.mail),
                                  title: const Text('Submit Requisition'),
                                  selected: _selectedIndex == 7,
                                  onTap: () {
                                    if (_selectedIndex == 7) return;
                                    // Update the state of the app
                                    // _onItemTapped(2);
                                    GoRouter.of(context).pop();
                                    GoRouter.of(context)
                                        .push("/user_requisition");
                                    setState(() {
                                      _selectedIndex = 7;
                                    });
                                    // Then close the drawer
                                  },
                                ),
                                ListTile(
                                  //show_requisition
                                  leading: const Icon(Icons.history),
                                  title: const Text('Show Requisition'),
                                  selected: _selectedIndex == 8,
                                  onTap: () {
                                    if (_selectedIndex == 8) return;
                                    // Update the state of the app
                                    // _onItemTapped(2);
                                    GoRouter.of(context).pop();
                                    GoRouter.of(context)
                                        .push("/show_requisition");
                                    // Then close the drawer
                                    setState(() {
                                      _selectedIndex = 8;
                                    });
                                  },
                                ),
                              ]),
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          selected: _selectedIndex == 9,
                          onTap: () {
                            if (_selectedIndex == 9) return;
                            GoRouter.of(context).pop();
                            GoRouter.of(context).push("/notifications");
                            setState(() {
                              _selectedIndex = 9;
                            });
                          },
                        ),
                        if (globel.userType == "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.car_repair),
                            title: const Text('Request Repair'),
                            selected: _selectedIndex == 15,
                            onTap: () {
                              if (_selectedIndex == 15) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer
                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/req_repair");
                              setState(() {
                                _selectedIndex = 15;
                              });
                            },
                          ),
                        if (globel.userType == "student")
                          ListTile(
                            leading: const Icon(Icons.qr_code),
                            title: const Text('QR Code'),
                            selected: _selectedIndex == 10,
                            onTap: () {
                              if (_selectedIndex == 10) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer

                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/qr_code");

                              setState(() {
                                _selectedIndex = 10;
                              });
                            },
                          ),
                        if (globel.userType == "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.manage_accounts),
                            title: const Text('Manage Trips'),
                            selected: _selectedIndex == 14,
                            onTap: () {
                              if (_selectedIndex == 14) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer

                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/manage_trips");

                              setState(() {
                                _selectedIndex = 14;
                              });
                            },
                          ),
                        if (globel.userType == "buet_staff")
                          ListTile(
                            leading: const Icon(Icons.payment),
                            title: const Text('Bill Payment'),
                            selected: _selectedIndex == 11,
                            onTap: () {
                              if (_selectedIndex == 11) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer
                              setState(() {
                                _selectedIndex = 11;
                              });
                            },
                          ),
                        if (globel.userType == "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.dashboard),
                            title: const Text('Dashboard'),
                            selected: _selectedIndex == 12,
                            onTap: () {
                              if (_selectedIndex == 12) return;
                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer
                              setState(() {
                                _selectedIndex = 12;
                              });
                            },
                          ),
                        if (globel.userType == "bus_staff")
                          ListTile(
                            leading: const Icon(Icons.qr_code),
                            title: const Text('QR Code Scan'),
                            selected: _selectedIndex == 13,
                            onTap: () {
                              if (_selectedIndex == 13) return;

                              // Update the state of the app
                              // _onItemTapped(2);
                              // Then close the drawer

                              GoRouter.of(context).pop();
                              GoRouter.of(context).push("/scan_qr_code");

                              setState(() {
                                _selectedIndex = 13;
                              });
                            },
                          ),
                        ListTile(
                          leading: const Icon(Icons.lock),
                          title: const Text('Change Password'),
                          selected: _selectedIndex == 16,
                          onTap: () {
                            if (_selectedIndex == 16) return;

                            GoRouter.of(context).pop();
                            GoRouter.of(context).push("/edit_password");
                            setState(() {
                              _selectedIndex = 16;
                            });
                          },
                        ),
                        ListTile(
                          visualDensity: const VisualDensity(vertical: 4),
                          leading: const Icon(Icons.logout),
                          title: const Text('Log out'),
                          selected: false,
                          onTap: () async {
                            context.loaderOverlay.show();
                            var r1 =
                                await Requests.post(globel.serverIp + 'logout');
                            r1.raiseForStatus();
                            dynamic json1 = r1.json();
                            if (json1['success']) {
                              await Requests.clearStoredCookies(
                                  globel.serverAddr);
                              globel.clearAll();
                              Fluttertoast.showToast(
                                  msg: 'Logged out.',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  timeInSecForIosWeb: 1,
                                  backgroundColor:
                                      Color.fromARGB(73, 77, 65, 64),
                                  textColor: Colors.white,
                                  fontSize: 16.0);
                            } else {
                              Fluttertoast.showToast(
                                  msg:
                                      'Something went wrong. Please restart the app.',
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  timeInSecForIosWeb: 1,
                                  backgroundColor:
                                      Color.fromARGB(73, 77, 65, 64),
                                  textColor: Colors.white,
                                  fontSize: 16.0);
                            }
                            GoRouter.of(context).go("/login");
                            context.loaderOverlay.hide();
                          },
                        ),
                      ],
                    ),
                  ],
                )),
          ),
        ),
      ),
    );
  }
}
