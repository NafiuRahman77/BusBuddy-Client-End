// a page containing the QR code only

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
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
  bool isTicketPresent = false;

  StreamSubscription? _messageSubscription;

  Future<void> getTicketInfo() async {
    context.loaderOverlay.show();
    try {
      var r = await Requests.post(globel.serverIp + 'getTicketQRData');

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
      dynamic json = r.json();
      print(json);

      if (json['success'] == true) {
        setState(() {
          ticket_id = json['ticket_id'];
          isTicketPresent = true;
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
        setState(() {
          ticket_id = "BLANK_TICKET";
          isTicketPresent = false;
        });
      }
      print(ticket_id);
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
  void initState() {
    super.initState();

    _messageSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // print("received ticket fcm: ${message.data}");
      if (message.data['nType'] == "ticket_used") {
        print("ticket got used");
        GoRouter.of(context).go("/show_profile");
      }
    });

    getTicketInfo();
    // setState(() {
    //   ticketController.text = '20';
    // });
  }

  @override
  void dispose() {
    _messageSubscription
        ?.cancel(); // Cancel the subscription when the page is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (isTicketPresent == true)
        ? Scaffold(
            body: Center(
              child: QrImageView(
                data: ticket_id,
                version: QrVersions.auto,
                size: 350.0,
              ),
            ),
          )
        : Scaffold(
            body: Center(
              child: Text(
                "No ticket found. Please try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  // You can also specify other text properties like color, font weight, etc. here.
                ),
              ),
            ),
          );
  }
}
