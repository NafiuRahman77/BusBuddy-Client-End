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
      Up_PrevPoint = [],
      Up_Route = []; // Added Up_Route list
  List<bool> Up_isliveara = [];
  List<String> Cur_Source_List = [],
      Cur_Destination_List = [],
      Cur_Start_Time = [],
      Cur_End_Time = [],
      Cur_BusNo = [],
      Cur_TripID = [],
      Cur_PrevPoint = [],
      Cur_Route = []; // Added Cur_Route list
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
      Up_Route.clear(); // Clearing Up_Route list
      Up_isliveara.clear();
      for (int i = 0; i < tripInformation['upcoming'].length; i++) {
        Up_Source_List.add("buet");
        Up_Destination_List.add("buet");
        Up_Start_Time.add(tripInformation['upcoming'][i]['start_timestamp']);
        if (tripInformation['upcoming'][i]['end_timestamp'] != null) {
          Up_End_Time.add(tripInformation['upcoming'][i]['end_timestamp']);
        } else {
          Up_End_Time.add("");
        }
        Up_BusNo.add(tripInformation['upcoming'][i]['bus']);
        Up_Route.add(
            tripInformation['upcoming'][i]['route']); // Adding Up_Route
        Up_TripID.add(tripInformation['upcoming'][i]['id']);
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
      Cur_Route.clear(); // Clearing Cur_Route list
      Cur_isliveara.clear();
      for (int i = 0; i < tripInformation['actual'].length; i++) {
        Cur_Source_List.add("buet");
        Cur_Destination_List.add("buet");
        Cur_Start_Time.add(tripInformation['actual'][i]['start_timestamp']);
        if (tripInformation['actual'][i]['end_timestamp'] != null) {
          Cur_End_Time.add(tripInformation['actual'][i]['end_timestamp']);
        } else {
          Cur_End_Time.add("");
        }
        Cur_BusNo.add(tripInformation['actual'][i]['bus']);
        Cur_Route.add(
            tripInformation['actual'][i]['route']); // Adding Cur_Route
        Cur_TripID.add(tripInformation['actual'][i]['id']);
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
                onTap: (index) {
                  print(index);
                  if (_tabController.indexIsChanging == false) {
                    GoRouter.of(context).push("/manage_trips");
                  }
                },
                tabs: [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Ongoing/History'),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
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
                    Route: Up_Route[index], // Passing Up_Route to TripCard
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
                    Route: Cur_Route[index], // Passing Cur_Route to TripCard
                    islive: Cur_isliveara[index],
                    parentReloadCallback: getTripInfo,
                    parentTabController: switchToUpcoming,
                    buttonColor: Colors.red,
                    title: "End Trip",
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
