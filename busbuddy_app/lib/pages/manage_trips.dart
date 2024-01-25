import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import '../components/TripCard.dart';

class ManageTrips extends StatefulWidget
{
  @override
  _ManageTripsState createState() => _ManageTripsState() ; 
}

class _ManageTripsState extends State<ManageTrips> {

  List<String> Source_List = [] ;
  List<String> Destination_List = [ ] ; 
  List<String> Start_Time = [] ; 
  List<String> End_Time = [] ; 
  List<String> BusNo = [] ; 
  List<String> TripID = [] ; 
  List<String> PrevPoint = [ ] ; 
  List<bool>  isliveara= [ ]  ; 

  @override
  void initState()
  {
    super.initState() ; 
    getTripInfo() ; 
  }


  Future<void> getTripInfo() async {
    context.loaderOverlay.show() ; 
    var r = await Requests.post(globel.serverIp + 'getStaffTrips');
    r.raiseForStatus(); 
    print(r.content()); 
    List<dynamic> tripInformation = r.json() ; 
    setState(() {
        for(int i=0 ; i<tripInformation.length ; i++)
        {
          // Source_List.add(tripInformation[i]['start_location']) ; 
          // Destination_List.add(tripInformation[i]['end_location']) ; 
          Source_List.add("buet") ; 
          Destination_List.add("buet") ; 
          Start_Time.add(tripInformation[i]['start_timestamp']) ;
          End_Time.add(tripInformation[i]['start_timestamp']) ; //jalal vua code lekhasie 
          BusNo.add(tripInformation[i]['bus']) ;
          TripID.add(tripInformation[i]['id']) ;
          // if(tripInformation[i]['prev_point']!=null)
          //   PrevPoint.add(tripInformation[i]['prev_point']);
          // else 
          //   PrevPoint.add("-1");
          PrevPoint.add("vua") ; 
          isliveara.add(false) ; 
        }
    });
    context.loaderOverlay.hide();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: Source_List.length,
          itemBuilder: (context,index)
          {
            return TripCard(
              SourceLocation: Source_List[index],
              DestinationLocation: Destination_List[index],
              StartTime: Start_Time[index],
              EndTime: End_Time[index],
              BusNo: BusNo[index],
              TripID: TripID[index],
              PrevP: PrevPoint[index],
              islive: isliveara[index],
              
       

            );

          },

        ),
      ),
    );
  }
}