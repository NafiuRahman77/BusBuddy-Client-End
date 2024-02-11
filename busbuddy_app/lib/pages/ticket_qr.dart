// a page containing the QR code only

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class TicketQR extends StatefulWidget {
  @override
  _TicketQRState createState() => _TicketQRState();
}

class _TicketQRState extends State<TicketQR> {
  int selectedTicket = 1; // Initialize with the first ticket
  int amount = 1 * 2;
  int currentTicket = 0;
  String studentName = "";
  String studentPhone = "";
  String studentEmail = "";
  String ticket_id = "BLANK_TICKET";

  Future<void> getTicketInfo() async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getTicketQRData');

    r.raiseForStatus();
    dynamic json = r.json();
    print(json);

    if (json['success'] == true) {
      setState(() {
        ticket_id = json['ticket_id'];
      });
    } else {
      Fluttertoast.showToast(
          msg: 'Failed to load data.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(118, 244, 67, 54),
          textColor: Colors.white,
          fontSize: 16.0);
    }
    print(ticket_id);
    context.loaderOverlay.hide();
  }

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("received ticket fcm: ${message.data}");
      print(message.data);
    });

    getTicketInfo();
    // setState(() {
    //   ticketController.text = '20';
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: QrImageView(
          data: ticket_id,
          version: QrVersions.auto,
          size: 350.0,
        ),
      ),
    );
  }
}
