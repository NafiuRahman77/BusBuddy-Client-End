import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class ReqRepair extends StatefulWidget {
  @override
  _ReqRepairState createState() => _ReqRepairState();
}

class _ReqRepairState extends State<ReqRepair> {
  String SelectedBus = "Mirpur 2";
  List<String> BusList = [];
  TextEditingController RepairController = TextEditingController();
  String SelectedParts = "Mirpur 2";
  List<String> Partslist = [];

  @override
  void initState() {
    super.initState();
    getBus();
    getParts();
  }

  Future<void> getBus() async {
    context.loaderOverlay.show();

    var r1 = await Requests.post(globel.serverIp + 'getRoutes');
    r1.raiseForStatus();
    List<dynamic> json1 = r1.json();
    setState(() {
      for (int i = 0; i < json1.length; i++) {
        BusList.add(json1[i]['terminal_point']);
      }
    });
    BusList.forEach((element) {
      print(element);
    });
    context.loaderOverlay.hide();
  }

  Future<bool> submitRequest() async {
    context.loaderOverlay.show();
    context.loaderOverlay.hide();
    return true;
  }

  Future<void> getParts() async {
    context.loaderOverlay.show();
    var r1 = await Requests.post(globel.serverIp + 'getRoutes');
    r1.raiseForStatus();
    List<dynamic> json1 = r1.json();
    setState(() {
      for (int i = 0; i < json1.length; i++) {
        Partslist.add(json1[i]['terminal_point']);
      }
    });
    Partslist.forEach((element) {
      print(element);
    });
    context.loaderOverlay.hide();
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Repair request submitted successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).go("/show_profile");
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
                  child: Text(
                    'Select Bus Number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: DropdownButtonFormField<String>(
                    value: SelectedBus,
                    onChanged: (value) {
                      setState(() {
                        // Handle dropdown selection
                        SelectedBus = value!;
                        // print(selectedOption);
                      });
                      //onRouteSelect(SelectedBusIndex);
                    },
                    items:
                        BusList.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
                  child: Text(
                    'Select Parts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: DropdownButtonFormField<String>(
                    value: SelectedParts,
                    onChanged: (value) {
                      setState(() {
                        // Handle dropdown selection
                        SelectedParts = value!;
                        // print(selectedOption);
                      });
                      //onRouteSelect(SelectedBusIndex);
                    },
                    items:
                        Partslist.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 16.0), // Add top padding
                child: Text(
                  'Request Details',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                      color:
                          Color.fromARGB(255, 237, 235, 235).withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: RepairController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter your request here',
                    hintStyle: TextStyle(
                        fontSize: 14.0,
                        color: Color.fromARGB(255, 135, 134, 134)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 16.0), // Add top padding
                child: Text(
                  'Repairment Details',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                      color:
                          Color.fromARGB(255, 237, 235, 235).withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: RepairController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter your repairment information',
                    hintStyle: TextStyle(
                        fontSize: 14.0,
                        color: Color.fromARGB(255, 135, 134, 134)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    print("clicked");
                    bool success = await submitRequest();
                    if (success) _showConfirmationDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                  ),
                  child: Text('Submit Request',
                      style: const TextStyle(
                        color: Colors.white,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
