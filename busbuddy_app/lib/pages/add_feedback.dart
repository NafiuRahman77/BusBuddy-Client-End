import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class FeedbackForm extends StatefulWidget {
  @override
  _FeedbackFormState createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  String selectedTopic = '';
  List<String> selectedSubject = [];
  bool isA = false;
  bool isB = false;
  bool isC = false;
  bool isD = false;
  bool confirmation = false;
  DateTime? selectedDate;
  TextEditingController feedbackController = TextEditingController();
  String defaultRoute = "";
  String defaultRouteName = "";
  String selectedRouteName = globel.userDefaultRouteName;
  String selectedRouteId = "";
  String selectedShift = "Morning";
  List<String> shiftList = ["Morning", "Afternoon", "Evening"];
  @override
  void initState() {
    super.initState();
    onCalendarMount();
  }

  void updateSelectedSubject(String subject) {
    setState(() {
      if (selectedSubject.contains(subject)) {
        selectedSubject.remove(subject);
      } else {
        selectedSubject.add(subject);
      }
    });
  }

  Future<void> onCalendarMount() async {
    context.loaderOverlay.show();
    globel.printWarning("hello");
    print(globel.routeNames);
    var r = await Requests.post(globel.serverIp + 'getDefaultRoute');

    r.raiseForStatus();
    dynamic json = r.json();

    if (json['success'] == true) {
      setState(() {
        defaultRoute = json['default_route'];
        defaultRouteName = json['default_route_name'];
      });
    } else {
      if (globel.userType != "student") {
        defaultRoute = "4";
      } else {
        Fluttertoast.showToast(
            msg: 'Failed to load default route.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Color.fromARGB(73, 77, 65, 64),
            textColor: Colors.white,
            fontSize: 16.0);
      }
    }
    print(r.content());

    for (int i = 0; i < globel.routeIDs.length; i++) {
      if (globel.routeIDs[i] == globel.userDefaultRouteId) {
        selectedRouteId = globel.routeIDs[i];
        selectedRouteName = globel.routeNames[i];
      }
    }

    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
    context.loaderOverlay.hide();
  }

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != selectedDate) {
      // Handle the selected date here, e.g., update a variable.
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Feedback submitted successfully!'),
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

  Future<bool> submitFeedback() async {
    context.loaderOverlay.show();
    String timestampStr;
    if (selectedDate == null)
      timestampStr = '';
    else
      timestampStr = selectedDate!.toIso8601String();

    if (!isA && !isB && !isC && !isD) {
      Fluttertoast.showToast(
          msg: 'Select at least one subject.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 77, 65, 64),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();

      return false;
    }

    if (feedbackController.text.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Please enter feedback details.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(73, 77, 65, 64),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return false;
    }

    var r = await Requests.post(globel.serverIp + 'addFeedback',
        body: {
          'route': selectedRouteId,
          'submission_timestamp': DateTime.now().toIso8601String(),
          'timestamp': timestampStr,
          //  'shift': selectedShift, // JALAL ETA BACKEND E ADD KORO
          'text': feedbackController.text,
          'subject': jsonEncode(selectedSubject),
        },
        bodyEncoding: RequestBodyEncoding.FormURLEncoded);

    r.raiseForStatus();
    dynamic json = r.json();

    print(r.content());

    // If the server did return a 201 CREATED response,
    // then parse the JSON.
    //print('bb: ${jsonDecode(response.body)['email']}');
    if (json['success'] == true) {
      Fluttertoast.showToast(
          msg: 'Feedback submitted.',
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
          msg: 'Error: Feedback not received by server.',
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
              SizedBox(height: 16.0),
              Container(
                margin: const EdgeInsets.only(left: 10.0),
                child: Text(
                  'Select Subject',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: isA,
                          onChanged: (value) {
                            setState(() {
                              isA = value!;
                              updateSelectedSubject("staff");
                            });
                          },
                          activeColor: Color(0xFF781B1B), // Change to red
                        ),
                        Text('Bus Staff'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: isB,
                          onChanged: (value) {
                            setState(() {
                              isB = value!;
                              updateSelectedSubject("driver");
                            });
                          },
                          activeColor: Color(0xFF781B1B), // Change to red
                        ),
                        Text('Bus Driver'),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: isC,
                          onChanged: (value) {
                            setState(() {
                              isC = value!;
                              updateSelectedSubject("bus");
                            });
                          },
                          activeColor: Color(0xFF781B1B), // Change to red
                        ),
                        Text('Bus Issue'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: isD,
                          onChanged: (value) {
                            setState(() {
                              isD = value!;
                              updateSelectedSubject("other");
                            });
                          },
                          activeColor: Color(0xFF781B1B), // Change to red
                        ),
                        Text('Others'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 16.0, bottom: 5), // Add top padding
                child: Text(
                  'Select Route',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Container(
                margin: const EdgeInsets.only(left: 8.0, right: 8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey.withOpacity(0.6)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 15, bottom: 5, right: 10),
                  child: DropdownButtonFormField<String>(
                    value: selectedRouteName,
                    onChanged: (value) {
                      setState(() {
                        // Handle dropdown selection
                        selectedRouteName = value!;
                        // print(selectedOption);
                        int idx = globel.routeNames.indexOf(selectedRouteName);
                        selectedRouteId = globel.routeIDs[idx];
                      });
                    },
                    items: globel.routeNames
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 16.0, bottom: 5), // Add top padding
                child: Text(
                  'Select Date',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 8.0, right: 8.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey.withOpacity(0.6)),
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
              SizedBox(height: 16.0),
              Container(
                margin: const EdgeInsets.only(left: 10.0, top: 16.0, bottom: 5),
                child: Text(
                  'Select Shift',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0, bottom: 5, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: shiftList.map((String value) {
                    return Row(
                      children: [
                        Radio<String>(
                          value: value,
                          groupValue: selectedShift,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedShift = newValue!;
                            });
                          },
                        ),
                        Text(value),
                      ],
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(
                    left: 10.0, top: 10.0), // Add top padding
                child: Text(
                  'Write Feedback',
                  style: TextStyle(
                    color: Color(0xFF781B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
              SizedBox(height: 8.0),
              Container(
                margin: const EdgeInsets.only(left: 8.0, right: 8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                      color:
                          Color.fromARGB(255, 237, 235, 235).withOpacity(0.1)),
                ),
                child: TextFormField(
                  controller: feedbackController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    // set position of hint text to top
                    contentPadding: EdgeInsets.only(top: 30, left: 10),
                    hintText: 'Enter your feedback here',
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
                    bool success = await submitFeedback();
                    if (success) _showConfirmationDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                  ),
                  child: Text('Submit Feedback',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
