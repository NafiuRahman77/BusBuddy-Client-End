import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import '../../globel.dart' as globel;

class TripCard extends StatefulWidget {
  final String SourceLocation;
  final String DestinationLocation;
  final String StartTime;
  final String EndTime;
  final String BusNo;
  final String TripID ; 
  final String PrevP ;
  final bool islive ; 


  TripCard({
    required this.SourceLocation,
    required this.DestinationLocation,
    required this.StartTime,
    required this.EndTime,
    required this.BusNo,
    required this.TripID ,
    required this.PrevP,
    required this.islive , 

  });

  @override
  _TripCardState createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  bool running_trip  = false ;
  Color buttonColor = Colors.green; 
  
  String buttonText1 = "Turn On GPS" ;
  String buttonText2 = "Turn Off GPS" ;  

  String buttontxt = "Turn On GPS" ;


  Map<String, String> getDateAndTime(String dateTimeString) {
  DateTime dateTime = DateTime.parse(dateTimeString);
  String formattedDate = DateFormat('yyyy-MM-dd').format(dateTime.toUtc());
  String formattedTime = DateFormat('HH:mm:ss').format(dateTime.toUtc());

    return {'Sdate': formattedDate, 'Stime': formattedTime};
}

  Future<bool> onTripStart(String tripID) async {
    context.loaderOverlay.show();
    var r2 = await Requests.post(globel.serverIp + 'startTrip',
        body: {
          'trip_id': tripID,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r2.raiseForStatus();

    dynamic json2 = r2.json();
    //print(json2);

      if(json2['success']==true)
      {
        context.loaderOverlay.hide();
        return true;
      }
    context.loaderOverlay.hide();
    return false;
  }


@override
Widget build(BuildContext context) {
  print(widget.SourceLocation);

  Map<String, String> Sdt = getDateAndTime(widget.StartTime);
  Map<String, String> Ddt = getDateAndTime(widget.EndTime);


  Duration remaining = DateTime.now().difference(DateTime.parse(widget.StartTime)) ;
  bool showWarning = false ; 
  if(remaining.inMinutes<10)showWarning=true ; 



  return Card(
    margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
      side: BorderSide(
        color: Colors.grey.withOpacity(0.3),
      ),
    ),
    child: InkWell(
      onTap: () {
        // Add functionality for the tap event
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: buildDataTable({
              'Source': widget.SourceLocation,
              'Destination': widget.DestinationLocation,
              'Start Date': Sdt['Sdate']!,
              'Start Time': Sdt['Stime']!,
              'End Date': Ddt['Sdate']!,
              'End Time': Ddt['Stime']!,
              'Bus No': widget.BusNo,
            }),
            ),
            
            SizedBox(height: 16),
            if(showWarning)
            Text(
              'Trip Scheduled in ${remaining.inMinutes} from now' , 
              style: TextStyle(
                color: Colors.red,
              ),
            ),

            if(running_trip) 
            Text(
              'The trip is running currenlty' , 
              style: TextStyle(
                color: Color.fromARGB(255, 38, 194, 27),
              ),
            ),
            
          
           

            SizedBox(height: 10) , 
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  bool startTrip =  await onTripStart(widget.TripID);
                  if(startTrip)
                  setState(() {
                 running_trip=!running_trip;
                 print(running_trip);
                 buttonColor = running_trip ? Colors.red : Colors.green;
                 buttontxt = running_trip ? buttonText2 : buttonText1 ; 
                    print(widget.TripID);
                  });
                },
                style: ElevatedButton.styleFrom(
                  primary: buttonColor,
                  onPrimary: Colors.white,
                ),
                child: Text(buttontxt),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
Widget buildDataTable(Map<String, String> data) {
  List<DataRow> rows = [];

  data.forEach((label, value) {
    rows.add(buildDataRow(label, value));
  });

  return DataTable(
    dataRowHeight: 50, // Adjust the row height as needed
    columns: [
      DataColumn(
        label: SizedBox.shrink(), // Hide the header
      ),
      DataColumn(
        label: SizedBox.shrink(), // Hide the header
      ),
    ],
    rows: rows,
  );
}

DataRow buildDataRow(String label, String value) {
  return DataRow(
    cells: [
      DataCell(
        Center(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataCell(
        Center(
          child: Text(value),
        ),
      ),
    ],
  );
}
