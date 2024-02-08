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
  String reasonForRequisition = "official";
  DateTime? selectedDate;

  TimeOfDay _selectedTime = TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _finishedTime = TimeOfDay(hour: 10, minute: 30);
  bool isCar = false;
  bool isMicroBus = false;
  String microSeatCapacity = "";
  bool isMiniBus = false;
  bool isBus = false;
  List<String> BusTypeSelected = [];
  String reportingLocation = "";
  String destination = '';

  String carSeatText = "";
  String miniBusCapacity = "";
  String busCapacity = "";
  String microBusCapacity = "";
  bool showMicroBusCapacity = false;
  @override
  void initState() {
    super.initState();
  }

  TextEditingController DestinationController = TextEditingController();
  TextEditingController ReportingController = TextEditingController();
  TextEditingController DescribeController = TextEditingController();

  void _showDatePicker() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
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

    if (!isCar && !isMicroBus && !isMiniBus && !isBus) {
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

    if (DescribeController.text.isEmpty) {
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
          'destination': DestinationController.text,
          'submission_timestamp': DateTime.now().toIso8601String(),
          'timestamp': timestampStr,
          'text': DescribeController.text,
          'bus_type': jsonEncode(BusTypeSelected),
          'source': ReportingController.text,
          'subject': reasonForRequisition
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              child: Text(
                                'Reason for Requisition',
                                style: TextStyle(
                                  color: Color(0xFF781B1B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: "official",
                                  groupValue: reasonForRequisition,
                                  onChanged: (value) {
                                    setState(() {
                                      reasonForRequisition = value as String;
                                    });
                                  },
                                ),
                                Text(
                                  'Official',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: "personal",
                                  groupValue: reasonForRequisition,
                                  onChanged: (value) {
                                    setState(() {
                                      reasonForRequisition = value as String;
                                    });
                                  },
                                ),
                                Text(
                                  'Personal',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: "BRTC",
                                  groupValue: reasonForRequisition,
                                  onChanged: (value) {
                                    setState(() {
                                      reasonForRequisition = value as String;
                                    });
                                  },
                                ),
                                Text(
                                  'BRTC',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Radio(
                                  value: "Others",
                                  groupValue: reasonForRequisition,
                                  onChanged: (value) {
                                    setState(() {
                                      reasonForRequisition = value as String;
                                    });
                                  },
                                ),
                                Text(
                                  'Others',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                  ),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
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
                                        color: const Color.fromARGB(
                                                255, 186, 185, 185)
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
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
                                        color: const Color.fromARGB(
                                                255, 186, 185, 185)
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
                          value: isCar,
                          onChanged: (value) {
                            setState(() {
                              if (BusTypeSelected.contains("car")) {
                                BusTypeSelected.remove("car");
                                carSeatText = '';
                              } else {
                                BusTypeSelected.add("car");
                                carSeatText = '4 seats';
                              }
                              isCar = !isCar;
                            });
                          },
                          activeColor: Color(0xFF781B1B),
                        ),
                      ),
                      Text(
                        'Car',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Text(
                        carSeatText,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Color(0xFF781B1B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Checkbox(
                          value: isMicroBus,
                          onChanged: (value) {
                            setState(() {
                              if (isMicroBus) {
                                BusTypeSelected.remove("Micro Bus");
                                microBusCapacity = '';
                                showMicroBusCapacity = false;
                                BusTypeSelected.removeWhere(
                                    (element) => element.startsWith("micro-"));
                              } else {
                                //BusTypeSelected.add("Micro Bus");
                                showMicroBusCapacity = true;
                              }
                              isMicroBus = !isMicroBus;
                            });
                          },
                          activeColor: Color(0xFF781B1B),
                        ),
                      ),
                      Text(
                        'Micro Bus',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      if (microBusCapacity != "")
                        Text(
                          microBusCapacity + " seats",
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Color(0xFF781B1B),
                          ),
                        ),
                    ],
                  ),
                  if (showMicroBusCapacity)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Radio(
                            value: "8",
                            groupValue: microBusCapacity,
                            onChanged: (value) {
                              setState(() {
                                microBusCapacity = value as String;
                                // Update BusTypeSelected array with microbus seat count
                                BusTypeSelected.removeWhere(
                                    (element) => element.startsWith("micro-"));
                                BusTypeSelected.add("micro-8");
                              });
                            },
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '8 seats',
                            style: TextStyle(
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Radio(
                            value: "12",
                            groupValue: microBusCapacity,
                            onChanged: (value) {
                              setState(() {
                                microBusCapacity = value as String;
                                // Update BusTypeSelected array with microbus seat count
                                BusTypeSelected.removeWhere(
                                    (element) => element.startsWith("micro-"));
                                BusTypeSelected.add("micro-12");
                              });
                            },
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '12 seats',
                            style: TextStyle(
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Radio(
                            value: "15",
                            groupValue: microBusCapacity,
                            onChanged: (value) {
                              setState(() {
                                microBusCapacity = value as String;
                                // Update BusTypeSelected array with microbus seat count
                                BusTypeSelected.removeWhere(
                                    (element) => element.startsWith("micro-"));
                                BusTypeSelected.add("micro-15");
                              });
                            },
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '15 seats',
                            style: TextStyle(
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Checkbox(
                          value: isMiniBus,
                          onChanged: (value) {
                            setState(() {
                              if (BusTypeSelected.contains("mini"))
                                BusTypeSelected.remove("mini");
                              else
                                BusTypeSelected.add("mini");
                              isMiniBus = !isMiniBus;
                              miniBusCapacity =
                                  miniBusCapacity == "" ? "30 seats" : "";
                            });
                          },
                          activeColor: Color(0xFF781B1B),
                        ),
                      ),
                      Text(
                        'Mini Bus',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Text(
                        miniBusCapacity,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Color(0xFF781B1B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Checkbox(
                          value: isBus,
                          onChanged: (value) {
                            setState(() {
                              if (BusTypeSelected.contains("normal"))
                                BusTypeSelected.remove("normal");
                              else
                                BusTypeSelected.add("normal");
                              isBus = !isBus;
                              busCapacity = busCapacity == "" ? "52 seats" : "";
                            });
                          },
                          activeColor: Color(0xFF781B1B),
                        ),
                      ),
                      Text(
                        'Bus',
                        style: TextStyle(
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(
                        width: 20,
                      ),
                      Text(
                        busCapacity,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Color(0xFF781B1B),
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
                      controller: ReportingController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Reporting location ',
                        hintStyle:
                            TextStyle(color: Colors.grey.withOpacity(0.8)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: TextFormField(
                      controller: DestinationController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter destination',
                        hintStyle:
                            TextStyle(color: Colors.grey.withOpacity(0.8)),
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
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Detailed Description ',
                        hintStyle:
                            TextStyle(color: Colors.grey.withOpacity(0.8)),
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
            ],
          ),
        ),
      ),
    );
  }
}
