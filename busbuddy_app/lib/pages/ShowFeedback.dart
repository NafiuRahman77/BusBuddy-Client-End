import 'package:flutter/material.dart';
import '../components/CollapsibleCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'dart:math';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class ShowFeedback extends StatefulWidget {
  @override
  _ShowFeedbackState createState() => _ShowFeedbackState();
}

class _ShowFeedbackState extends State<ShowFeedback> {
  List<String> time_list = [];
  List<String> subject_list = [];
  List<String> feedback_list = [];
  List<String> response_list = [];
  List<String> route_list = [];

  @override
  void initState() {
    super.initState();
    getFeedbackInfo();
  }

  Future<void> getFeedbackInfo() async {
    context.loaderOverlay.show();

    var r = await Requests.post(globel.serverIp + 'getUserFeedback');
    r.raiseForStatus();
    print("receiving ? ");
    print(r.content());
    print("done ?");

    List<dynamic> json = r.json();

    setState(() {
      for (int i = 0; i < json.length; i++) {
        time_list.add(json[i]['submission_timestamp']);
        route_list.add(json[i]['route_name']);
        feedback_list.add(json[i]['text']);
        subject_list.add(json[i]['subject']);
        if (json[i]['response'] != null)
          response_list.add(json[i]['response']);
        else
          response_list.add('');
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
          itemCount: feedback_list.length,
          itemBuilder: (context, index) {
            return CollapsibleCard(
              subject: subject_list[index],
              shortMessage: feedback_list[index],
              fullMessage: feedback_list[index],
              responseMessage:
                  response_list[index].isEmpty ? '' : response_list[index],
              date: time_list[index].substring(0, 10),
              route: route_list[index],
           
            );
          },
        ),
      ),
    );
  }
}
