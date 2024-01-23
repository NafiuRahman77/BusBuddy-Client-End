import 'package:flutter/material.dart';
import '../components/Req_CollapsibleCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'dart:math';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class ShowRequisition extends StatefulWidget {
  @override
  _ShowRequisitionState createState() => _ShowRequisitionState();
}

class _ShowRequisitionState extends State<ShowRequisition> {
  List<String> time_list = [];
  List<String> subject_list = [];
  List<String> description_list = [];
  List<String> approved_list = [];
  List<String> route_list = [];
  List<String> bus_type_list = [];

  @override
  void initState() {
    super.initState();
    getFeedbackInfo();
  }

  Future<void> getFeedbackInfo() async {
    context.loaderOverlay.show();

    var r = await Requests.post(globel.serverIp + 'getUserRequisition');
    r.raiseForStatus();
    print("receiving ? ");
    print(r.content());
    print("done ?");

    List<dynamic> json = r.json();

    setState(() {
      for (int i = 0; i < json.length; i++) {
        time_list.add(json[i]['timestamp']);
        route_list.add(json[i]['destination']);
        description_list.add(json[i]['text']);
        subject_list.add(json[i]['subject']);
        bus_type_list.add(json[i]['bus_type']);
        if (json[i]['approved_by'] != null)
          approved_list.add(json[i]['approved_by']);
        else
          approved_list.add('');
      }
    });
    subject_list.forEach((element) {
      print(element);
    });
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: description_list.length,
          itemBuilder: (context, index) {
            return Req_CollapsibleCard(
              subject: subject_list[index],
              shortMessage: description_list[index],
              fullMessage: description_list[index],
              verdict: approved_list[index].isEmpty ? '' : approved_list[index],
              date: time_list[index].substring(0, 10),
              location: route_list[index],
              bus_type: bus_type_list[index],
            );
          },
        ),
      ),
    );
  }
}
