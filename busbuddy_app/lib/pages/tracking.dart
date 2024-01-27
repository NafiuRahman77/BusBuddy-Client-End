import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/CustomCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import './trackingMap.dart';

class Tracking extends StatefulWidget {
  @override
  _trackingState createState() => _trackingState();
}

class _trackingState extends State<Tracking> {
    @override
  Widget build(BuildContext context) {
    return Scaffold(
                body:Center(
                child: ElevatedButton(
                  onPressed: () async {
                    print("clicked");
                    String RouteID = "3" ; 
                    GoRouter.of(context).push("/trackingmap" , extra: RouteID) ;
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                  ),
                  child: Text('Show map',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
    );
  }
}

