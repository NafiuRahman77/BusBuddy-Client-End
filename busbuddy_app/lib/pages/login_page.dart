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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // text editing controllers
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<bool> onLogin(String id, String password) async {
    // final response = await http.post(
    //   Uri.parse(globel.serverIp + 'login'),
    //   headers: <String, String>{
    //     'Content-Type': 'application/json; charset=UTF-8',
    //   },
    //   body: jsonEncode(<String, String>{'id': id, 'password': password}),
    // );
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'login',
        body: {
          'id': id,
          'password': password,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    print(json['success']);

    // var r2 = await Requests.post(globel.serverIp + 'getProfile');

    // r2.raiseForStatus();
    // dynamic json2 = r2.json();
    // print(r2.content());

    if (json['success'] == true) {
      globel.userType = json['user_type'] ; 
      print(globel.userType) ; 
      Fluttertoast.showToast(
          msg: 'Welcome, ${json['name']}',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 56, 52, 52),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
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
    context.loaderOverlay.hide();
    return false;
  }
  // sign user in method

  Future<void> onProfileReady() async {
    context.loaderOverlay.show();

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
    context.loaderOverlay.hide();
  }

  Future<void> onProfileMount() async {
    context.loaderOverlay.show();
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
        if(globel.userType=="student")
        {        
        globel.userEmail = json['email'];
        globel.userDefaultRouteId = json['default_route'];
        globel.userDefaultRouteName = json['default_route_name'];
        globel.userDefaultStationId = json['default_station'];
        globel.userDefaultStationName = json['default_station_name'];
        }
        else if(globel.userType=="buet_staff")
        {
          globel.teacherDepartment = json['department'] ; 
          globel.teacherDesignation = json['designation'] ; 
          globel.teacherResidence = json['residence'] ; 

        }
        else if(globel.userType=="bus_staff"){
           globel.staffRole = json['role'] ; 
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
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: Color.fromARGB(150, 200, 200, 200),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEB2A2A)!, Color.fromARGB(255, 21, 21, 21)!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),

                    // welcome back, you've been missed!
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

                    Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    // username textfield
                    MyTextField(
                      controller: usernameController,
                      hintText: 'Username',
                      obscureText: false,
                    ),

                    const SizedBox(height: 50),

                    // password textfield
                    MyTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      obscureText: true,
                    ),

                    const SizedBox(height: 25),

                    // sign in button
                    MyButton(onTap: () async {
                      //GoRouter.of(context).go("/show_profile");
                      bool lgin = await onLogin(
                          usernameController.text, passwordController.text);
                      if (lgin == true) {
                        await onProfileReady();
                        await onProfileMount();
                        GoRouter.of(context).go("/show_profile");
                      }
                    }),

                    const SizedBox(height: 50),

                    const SizedBox(height: 10),

                    // forgot password?
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment
                            .center, // Center the text horizontally
                        children: [
                          Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 50),

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
