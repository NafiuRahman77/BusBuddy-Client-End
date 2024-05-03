import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    try {
      var r = await Requests.post(globel.serverIp + 'getUserFeedback');
      r.raiseForStatus();
      if (r.statusCode == 401) {
        await Requests.clearStoredCookies(globel.serverAddr);
        globel.clearAll();
        Fluttertoast.showToast(
            msg: 'Not authenticated / authorised.',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 1,
            backgroundColor: Color.fromARGB(71, 211, 59, 45),
            textColor: Colors.white,
            fontSize: 16.0);
        context.loaderOverlay.hide();
        GoRouter.of(context).go("/login");
        return;
      }
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
    } catch (err) {
      globel.printError(err.toString());
      setState(() {
        context.loaderOverlay.hide();
      });

      Fluttertoast.showToast(
          msg: 'Failed to reach server. Try again.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(209, 194, 16, 0),
          textColor: Colors.white,
          fontSize: 16.0);
      GoRouter.of(context).pop();
    }
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
