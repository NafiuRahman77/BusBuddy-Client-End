import 'package:busbuddy_app/components/RepairCollapsibleCard.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../components/CollapsibleCard.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'dart:math';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class ShowRepair extends StatefulWidget {
  @override
  _ShowRepairState createState() => _ShowRepairState();
}

class _ShowRepairState extends State<ShowRepair> {
  List<String> time_list = [];
  List<String> bus_list = [];
  List<String> parts_list = [];
  List<String> request_list = [];
  List<String> repair_list = [];
  List<String> response_list = [];

  @override
  void initState() {
    super.initState();
    getFeedbackInfo();
  }

  Future<void> getFeedbackInfo() async {
    context.loaderOverlay.show();

    var r = await Requests.post(globel.serverIp + 'getRepairRequests');
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
        bus_list.add(json[i]['bus']);
        parts_list.add(json[i]['parts']);
        time_list.add(json[i]['timestamp']);
        request_list.add(json[i]['request_des']);
        repair_list.add(json[i]['repair_des']);

        if (json[i]['response'] != null)
          response_list.add(json[i]['response']);
        else
          response_list.add('');
      }
    });
    bus_list.forEach((element) {
      print(element);
    });
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView.builder(
          itemCount: bus_list.length,
          itemBuilder: (context, index) {
            return RepairCollapsibleCard(
              bus: bus_list[index],
              parts: parts_list[index],
              request_description: request_list[index],
              responseMessage:
                  response_list[index].isEmpty ? '' : response_list[index],
              date: time_list[index].substring(0, 10),
              repair_description: repair_list[index],
            );
          },
        ),
      ),
    );
  }
}
