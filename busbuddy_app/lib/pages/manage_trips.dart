import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;
import '../components/TripCard.dart';

class ManageTrips extends StatefulWidget {
  @override
  _ManageTripsState createState() => _ManageTripsState();
}

class _ManageTripsState extends State<ManageTrips>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> Up_Source_List = [],
      Up_Destination_List = [],
      Up_Start_Time = [],
      Up_End_Time = [],
      Up_BusNo = [],
      Up_TripID = [],
      Up_PrevPoint = [];
  List<bool> Up_isliveara = [];
  List<String> Cur_Source_List = [],
      Cur_Destination_List = [],
      Cur_Start_Time = [],
      Cur_End_Time = [],
      Cur_BusNo = [],
      Cur_TripID = [],
      Cur_PrevPoint = [];
  List<bool> Cur_isliveara = [];

  @override
  void initState() {
    super.initState();
    getTripInfo();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> getTripInfo() async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getStaffTrips');
    r.raiseForStatus();
    print(r.content());
    dynamic tripInformation = r.json();
    if (tripInformation['success'] == false) return;

    setState(() {
      Up_Source_List.clear();
      Up_Destination_List.clear();
      Up_Start_Time.clear();
      Up_End_Time.clear();
      Up_BusNo.clear();
      Up_TripID.clear();
      Up_PrevPoint.clear();
      Up_isliveara.clear();
      for (int i = 0; i < tripInformation['upcoming'].length; i++) {
        // Source_List.add(tripInformation[i]['start_location']) ;
        // Destination_List.add(tripInformation[i]['end_location']) ;
        Up_Source_List.add("buet");
        Up_Destination_List.add("buet");
        Up_Start_Time.add(tripInformation['upcoming'][i]['start_timestamp']);
        Up_End_Time.add(tripInformation['upcoming'][i]
            ['start_timestamp']); //jalal vua code lekhasie
        Up_BusNo.add(tripInformation['upcoming'][i]['bus']);
        Up_TripID.add(tripInformation['upcoming'][i]['id']);
        // if(tripInformation[i]['prev_point']!=null)
        //   PrevPoint.add(tripInformation[i]['prev_point']);
        // else
        //   PrevPoint.add("-1");
        Up_PrevPoint.add("vua");
        Up_isliveara.add(false);
      }
      Cur_Source_List.clear();
      Cur_Destination_List.clear();
      Cur_Start_Time.clear();
      Cur_End_Time.clear();
      Cur_BusNo.clear();
      Cur_TripID.clear();
      Cur_PrevPoint.clear();
      Cur_isliveara.clear();
      for (int i = 0; i < tripInformation['actual'].length; i++) {
        // Source_List.add(tripInformation[i]['start_location']) ;
        // Destination_List.add(tripInformation[i]['end_location']) ;
        Cur_Source_List.add("buet");
        Cur_Destination_List.add("buet");
        Cur_Start_Time.add(tripInformation['actual'][i]['start_timestamp']);
        Cur_End_Time.add(tripInformation['actual'][i]
            ['start_timestamp']); //jalal vua code lekhasie
        Cur_BusNo.add(tripInformation['actual'][i]['bus']);
        Cur_TripID.add(tripInformation['actual'][i]['id']);
        // if(tripInformation[i]['prev_point']!=null)
        //   PrevPoint.add(tripInformation[i]['prev_point']);
        // else
        //   PrevPoint.add("-1");
        Cur_PrevPoint.add("vua");
        Cur_isliveara.add(tripInformation['actual'][i]['is_live']);
      }
    });
    context.loaderOverlay.hide();
  }

  void switchToOngoing() {
    setState(() {
      _tabController.index = 1;
    });
  }

  void switchToUpcoming() {
    setState(() {
      _tabController.index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: null,
              flexibleSpace: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Ongoing/History'),
                    ],
                  ),
                ],
              ),
            ),
            body: TabBarView(controller: _tabController, children: [
              //Upcoming trips view
              Center(
                child: ListView.builder(
                  itemCount: Up_Source_List.length,
                  itemBuilder: (context, index) {
                    return TripCard(
                      SourceLocation: Up_Source_List[index],
                      DestinationLocation: Up_Destination_List[index],
                      StartTime: Up_Start_Time[index],
                      EndTime: Up_End_Time[index],
                      BusNo: Up_BusNo[index],
                      TripID: Up_TripID[index],
                      PrevP: Up_PrevPoint[index],
                      islive: Up_isliveara[index],
                      parentReloadCallback: getTripInfo,
                      parentTabController: switchToOngoing,
                      buttonColor: Colors.green,
                      title: "Start Trip",
                    );
                  },
                ),
              ),
              //Actual trips view
              Center(
                child: ListView.builder(
                  itemCount: Cur_Source_List.length,
                  itemBuilder: (context, index) {
                    return TripCard(
                      SourceLocation: Cur_Source_List[index],
                      DestinationLocation: Cur_Destination_List[index],
                      StartTime: Cur_Start_Time[index],
                      EndTime: Cur_End_Time[index],
                      BusNo: Cur_BusNo[index],
                      TripID: Cur_TripID[index],
                      PrevP: Cur_PrevPoint[index],
                      islive: Cur_isliveara[index],
                      parentReloadCallback: getTripInfo,
                      parentTabController: switchToUpcoming,
                      buttonColor: Colors.red,
                      title: "End Trip",
                    );
                  },
                ),
              ),
            ])));
  }
}
