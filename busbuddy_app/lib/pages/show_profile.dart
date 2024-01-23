import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

Widget buildInfoRow(String label, String value) {
  return Row(
    children: <Widget>[
      Flexible(
        flex: 1,
        fit: FlexFit.tight,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Flexible(
        flex: 2,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14.0,
          ),
        ),
      ),
    ],
  );
}



Widget buildUserInfoCard() {
  return Card(
    color: Color.fromARGB(223, 255, 255, 255),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          buildInfoRow('Route:', globel.userDefaultRouteName),
          SizedBox(height: 12.0),
          buildInfoRow('Station:', globel.userDefaultStationName),
          SizedBox(height: 12.0),
          buildInfoRow('Mobile No:', globel.userPhone),
          SizedBox(height: 12.0),
          buildInfoRow('Email:', globel.userEmail),
        ],
      ),
    ),
  );
}

Widget buildTeacherInfoCard() {
  return Card(
    color: Color.fromARGB(223, 255, 255, 255),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          buildInfoRow('Department:', globel.teacherDepartment),
          SizedBox(height: 12.0),
          buildInfoRow('Designation:', globel.teacherDesignation),
          SizedBox(height: 12.0),
          buildInfoRow('Residence:', globel.teacherResidence),
          SizedBox(height: 12.0),
          buildInfoRow('Phone:', globel.userPhone),
      
        ],
      ),
    ),
  );
}


Widget buildBusStaffInfoCard() {
  return Card(
    color: Color.fromARGB(223, 255, 255, 255),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          buildInfoRow('Role:', globel.staffRole),
          SizedBox(height: 12.0),
          buildInfoRow('Mobile No:', globel.userPhone),
        ],
      ),
    ),
  );
}
class ShowProfile extends StatefulWidget {
  @override
  _ShowProfileState createState() => _ShowProfileState();
}

class _ShowProfileState extends State<ShowProfile> {
  final double profileHeight = 144;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
        children: <Widget>[
          SizedBox(height: 52.0),
          buildProfilePicture(),
          SizedBox(height: 28.0),
          buildContent(),
          SizedBox(height: 28.0),
          buildEditProfileButton(),
        ],
      ),
    );
  }

  Widget buildContent() {
      Widget userCard = buildUserInfoCard();

    if (globel.userType == "student") {
      userCard = buildUserInfoCard();
    } else if (globel.userType == "buet_staff") {
      userCard = buildTeacherInfoCard();
    } else if(globel.userType == "bus_staff"){
      userCard = buildBusStaffInfoCard() ; 
    }
    
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            globel.userName,
            style: TextStyle(
              color: Color.fromARGB(255, 5, 101, 146),
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.0),
          Text(
            'User ID: ${globel.userId}',
            style: TextStyle(fontSize: 16.0),
          ),
          SizedBox(height: 12.0),
          Text(
            '${globel.userType}' , 
            style: TextStyle(fontSize: 16.0),
          ),
          SizedBox(height: 40.0),
          userCard,
        ],
      ),
    );
  }

  Widget buildProfilePicture() {
    return Center(
      child: CircleAvatar(
        radius: profileHeight / 2,
        backgroundColor: Colors.white,
        backgroundImage: globel.userAvatar,
      ),
    );
  }

  Widget buildEditProfileButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80.0),
      child: ElevatedButton(
        onPressed: () {
          // Handle the "Edit Profile" button action
          GoRouter.of(context).push("/edit_profile");
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF781B1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
        ),
        child: Text('Edit Profile', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
