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


  List<dynamic> trackingData = [];
  List<dynamic> station_coords = [];
  bool loadedRouteTimeData = false;
  void initState() {
    super.initState();
    getPoints("6") ; 
  }
  Future<void> getPoints(String RouteID) async {
  
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getTrackingData',
        body: {
          'route': RouteID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    setState(() {
    trackingData = r.json();
    loadedRouteTimeData = true;
    print(trackingData) ; 
    // for(int i=0 ; i<trackingData.length ; i++)
    // {
    //   List<dynamic> pathCoords = trackingData[i]['path'] ;
    // }
     
  
  


    });
    context.loaderOverlay.hide();
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
               body: Center(
              child: ListView.builder(
              itemCount: trackingData.length,
              itemBuilder: (context, index) {
                return ElevatedButton(
                  onPressed: () async {
                    print("clicked");
                    
                    List<dynamic> pathCoords = trackingData[index]['path'];


                  GoRouter.of(context).push("/trackingmap", extra: {'TripID' : trackingData[index]['id']  ,'pathCoords' :pathCoords});
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                  ),
                  child: Text('Show map',
                      style: TextStyle(color: Colors.white)),
                      );
                },
        ),
      ),
    );
  }
}
