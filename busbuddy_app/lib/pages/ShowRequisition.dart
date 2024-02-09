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
  List<String> timeList = [];
  List<String> reasonList = [];
  List<String> descriptionList = [];
  List<String> approvedList = [];
  List<String> routeList = [];
  List<String> bustypeList = [];
  List<String> sourceList = [];

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
        timeList.add(json[i]['timestamp']);
        routeList.add(json[i]['destination']);
        descriptionList.add(json[i]['text']);
        reasonList.add(json[i]['subject']);
        bustypeList.add(json[i]['bus_type']);
        if (json[i]['approved_by'] != null)
          approvedList.add(json[i]['approved_by']);
        else
          approvedList.add('');
        sourceList.add(json[i]['source']);
      }
    });
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: descriptionList.length,
          itemBuilder: (context, index) {
            return Req_CollapsibleCard(
              subject: reasonList[index],
              shortMessage: descriptionList[index],
              fullMessage: descriptionList[index],
              verdict: approvedList[index].isEmpty ? '' : approvedList[index],
              date: timeList[index].substring(0, 10),
              location: routeList[index],
              bus_type: bustypeList[index],
              source: sourceList[index],
            );
          },
        ),
      ),
    );
  }
}
