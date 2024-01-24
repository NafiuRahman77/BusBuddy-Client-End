import 'dart:convert';

import 'package:busbuddy_app/pages/scan_ticket_qr.dart';
import 'package:busbuddy_app/pages/ticket_qr.dart';

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
import 'pages/ShowRequisition.dart';
import 'package:requests/requests.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'globel.dart' as globel;

void main() {
  initializeShurjopay(environment: "sandbox");
  runApp(BusBuddyApp());
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
        builder: ((context, state) => const HomeView(page: "Route Calendar"))),
    GoRoute(
        path: "/routetimemap",
        builder: ((context, state) => const HomeView(page: "Route Map"))),
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
  PageBody(this.page);
  String page;
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
      return RouteTimeMap();
    else if (this.page == "User Requisition")
      return Requisition();
    else if (this.page == "Feedback Response")
      return ShowFeedback();
    else if (this.page == "Show Requisition")
      return ShowRequisition();
    else if (this.page == "QR Code")
      return TicketQR();
    else if (this.page == "Scan QR Code") return ScanTicketQR();
    return (Container());
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.page});
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String page;

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
    } else {
      _selectedIndex = 0;
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
        body: PageBody(widget.page),
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
                            // Update the state of the app
                            // _onItemTapped(2);
                            // Then close the drawer
                            setState(() {
                              _selectedIndex = 9;
                            });
                          },
                        ),
                        if (globel.userType != "buet_staff")
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
                                  "18.117.93.134:6969");
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
