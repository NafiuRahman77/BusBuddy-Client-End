import 'package:flutter/material.dart';
import '../components/my_textfield.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'dart:convert';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class Requisition extends StatefulWidget {
  @override
  _RequisitionState createState() => _RequisitionState();
}

class _RequisitionState extends State<Requisition> {
  DateTime? selectedDate;

  TimeOfDay _selectedTime = TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _finishedTime = TimeOfDay(hour: 10, minute: 30);

  @override
  void initState() {
    super.initState();
  }

  List<String> BusTypeSelected = [];
  String location = '';

  bool isA = false;
  bool isB = false;
  bool isC = false;
  bool isD = false;

  TextEditingController RequestController = TextEditingController();
  TextEditingController LocationController = TextEditingController();
  TextEditingController DescribeController = TextEditingController();

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _showTimePicker() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _showTimePicker2() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _finishedTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _finishedTime = pickedTime;
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Requisition submitted successfully!'),
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

  Future<bool> submitRequisition() async {
    context.loaderOverlay.show();
    String timestampStr;
    String combinedStr = ' ';
    if (selectedDate != null) {
      String dateStr =
          "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

      String timeStr =
          "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

      combinedStr = "$dateStr $timeStr";

      print(combinedStr);
    }

    if (selectedDate == null)
      timestampStr = '';
    else
      timestampStr = combinedStr;

    if (!isA && !isB && !isC && !isD) {
      Fluttertoast.showToast(
          msg: 'Select at least one bus type.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 77, 65, 64),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return false;
    }

    if (RequestController.text.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Please enter Requisition details.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 77, 65, 64),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return false;
    }

    var r = await Requests.post(globel.serverIp + 'addRequisition',
        body: {
          'destination': LocationController.text,
          'submission_timestamp': DateTime.now().toIso8601String(),
          'timestamp': timestampStr,
          'text': DescribeController.text,
          'bus_type': jsonEncode(BusTypeSelected),
          'subject': RequestController.text,
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    print(r.content());

    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(r.body)['email']}');
    if (json['success'] == true) {
      Fluttertoast.showToast(
          msg: 'Requisition submitted.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(131, 71, 62, 62),
          textColor: Colors.white,
          fontSize: 16.0);
      setState(() {
        // email = json['email'];
        // phoneNo = json['phone'];
        // defaultRoute = json['default_route'];

        // id = json['id'];
      });
      context.loaderOverlay.hide();
      return true;
    } else {
      Fluttertoast.showToast(
          msg: 'Error: Requisition not received by server.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(97, 212, 33, 21),
          textColor: Colors.white,
          fontSize: 16.0);
    }
    context.loaderOverlay.hide();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: MaterialButton(
                        onPressed: _showDatePicker,
                        child: Text(
                          selectedDate != null
                              ? selectedDate.toString().split(' ')[0]
                              : 'Choose Date',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15.0),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Start Time:',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showTimePicker,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        const Color.fromARGB(255, 186, 185, 185)
                                            .withOpacity(0.3)),
                              ),
                              margin: const EdgeInsets.all(10.0),
                              padding: const EdgeInsets.all(5.0),
                              child: Text(
                                _selectedTime.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 15.0),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'End Time:',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showTimePicker2,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color:
                                        const Color.fromARGB(255, 186, 185, 185)
                                            .withOpacity(0.3)),
                              ),
                              margin: const EdgeInsets.all(10.0),
                              padding: const EdgeInsets.all(5.0),
                              child: Text(
                                _finishedTime.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Container(
                margin: const EdgeInsets.only(left: 10.0),
                child: Text(
                  'Select Bus Type',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Checkbox(
                      value: isA,
                      onChanged: (value) {
                        setState(() {
                          if (BusTypeSelected.contains("single_decker"))
                            BusTypeSelected.remove("single_decker");
                          else
                            BusTypeSelected.add("single_decker");
                          isA = !isA;
                        });
                      },
                      activeColor: Color(0xFF781B1B), // Change to red
                    ),
                  ),
                  Text(
                    'Single Decker',
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10, left: 2),
                    child: Checkbox(
                      value: isB,
                      onChanged: (value) {
                        setState(() {
                          if (BusTypeSelected.contains("double_decker"))
                            BusTypeSelected.remove("double_decker");
                          else
                            BusTypeSelected.add("double_decker");
                          isB = !isB;
                        });
                      },
                      activeColor: Color(0xFF781B1B), // Change to red
                    ),
                  ),
                  Text(
                    'Double Decker',
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Checkbox(
                      value: isC,
                      onChanged: (value) {
                        setState(() {
                          if (BusTypeSelected.contains("micro"))
                            BusTypeSelected.remove("micro");
                          else
                            BusTypeSelected.add("micro");
                          isC = !isC;
                        });
                      },
                      activeColor: Color(0xFF781B1B), // Change to red
                    ),
                  ),
                  Text(
                    'Micro Bus',
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  SizedBox(
                    width: 30.0,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Checkbox(
                      value: isD,
                      onChanged: (value) {
                        setState(() {
                          if (BusTypeSelected.contains("mini"))
                            BusTypeSelected.remove("mini");
                          else
                            BusTypeSelected.add("mini");
                          isD = !isD;
                        });
                      },
                      activeColor: Color(0xFF781B1B), // Change to red
                    ),
                  ),
                  Text(
                    'Mini Bus',
                    style: TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 30.0,
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: LocationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter detailed location here ',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 30.0,
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: RequestController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Subject ',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                height: 30.0,
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: DescribeController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Description ',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    print("clicked");
                    bool success = await submitRequisition();
                    if (success) _showConfirmationDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                  ),
                  child: Text('Submit Requisition',
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
