import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shurjopay/shurjopay.dart';
import 'package:shurjopay/models/config.dart';
import 'package:shurjopay/models/payment_verification_model.dart';
import 'package:shurjopay/models/shurjopay_request_model.dart';
import 'package:shurjopay/models/shurjopay_response_model.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'dart:math';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

class TicketChoose extends StatefulWidget {
  @override
  _TicketChooseState createState() => _TicketChooseState();
}

class _TicketChooseState extends State<TicketChoose> {
  int selectedTicket = 50; // Initialize with the first ticket
  int amount = 2 * 50;
  int currentTicket = 20;
  String studentName = "";
  String studentPhone = "";
  String studentEmail = "";

  @override
  void initState() {
    super.initState();
    getTicketInfo();
    // setState(() {
    //   ticketController.text = '20';
    // });
  }

  Future<void> getTicketInfo() async {
    context.loaderOverlay.show();
    try {
      var r = await Requests.post(globel.serverIp + 'getTicketCount');

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

      if (json['success'] == true) {
        setState(() {
          currentTicket = int.parse(json['count']);
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
    } catch (err) {
      globel.printError(err.toString());
      context.loaderOverlay.hide();

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

  final ticketController = TextEditingController();
  ShurjoPay shurjoPay = ShurjoPay();

  ShurjopayConfigs shurjopayConfigs = ShurjopayConfigs(
    prefix: "sp",
    userName: "sp_sandbox",
    password: "pyyk97hu&6u6",
    clientIP: "127.0.0.1",
  );

  ShurjopayResponseModel shurjopayResponseModel = ShurjopayResponseModel();
  ShurjopayVerificationModel shurjopayVerificationModel =
      ShurjopayVerificationModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.0),
            Center(
              child: Text(
                'Current Tickets :',
                style: TextStyle(
                  color: Color(0xFF781B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 30.0,
                ),
              ),
            ),
            Center(
              child: Text(
                '$currentTicket',
                style: TextStyle(
                  color: Color(0xFF781B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 80.0,
                ),
              ),
            ),

            // Title: Choose Your Amount

            SizedBox(height: 60.0),

            Center(
              child: Text(
                'Select number of tickets you want to buy',
                style: TextStyle(
                  color: Color(0xFF781B1B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                ),
              ),
            ),

            SizedBox(height: 16.0), // Add spacing below the title

            // Box-like Shape Content
            Container(
              margin: const EdgeInsets.all(10.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                border: Border.all(color: Color.fromARGB(255, 236, 237, 237)),
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 252, 252, 252)
                        .withOpacity(0.5), // Shadow color
                    spreadRadius: 5, // Spread radius
                    blurRadius: 7, // Blur radius
                    offset: Offset(0, 3), // Offset
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left: Rectangular Image
                  const Icon(size: 50, Icons.confirmation_num),

                  SizedBox(width: 16.0), // Add some spacing between elements

                  // Middle: Ticket Amount Text
                  Expanded(
                    child: Text(
                      'Price: ৳${selectedTicket * 2}', // Assuming each ticket costs $100
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),

                  SizedBox(width: 16.0), // Add some spacing between elements

                  // Inside your build method
                  DropdownButton<int>(
                    value: selectedTicket,
                    // add some styling to the dropdown button
                    style: TextStyle(color: Color(0xFF781B1B), fontSize: 16.0),
                    underline: Container(
                      height: 2,
                      width: 2,
                      color: Color(0xFF781B1B),
                    ),
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          selectedTicket = value;
                          amount = selectedTicket * 2;
                          ticketController.text = selectedTicket.toString();
                        });
                      }
                    },

                    items: [
                      DropdownMenuItem<int>(
                        value: 50,
                        child: Text('50'),
                      ),
                      DropdownMenuItem<int>(
                        value: 100,
                        child: Text('100'),
                      ),
                      DropdownMenuItem<int>(
                        value: 200,
                        child: Text('200'),
                      ),
                      DropdownMenuItem<int>(
                        value: 500,
                        child: Text('500'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.0),

            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(color: Color.fromARGB(255, 236, 237, 237)),
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 252, 252, 252)
                        .withOpacity(0.5), // Shadow color
                    spreadRadius: 5, // Spread radius
                    blurRadius: 7, // Blur radius
                    offset: Offset(0, 3), // Offset
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 0),
                child: DropdownButtonFormField<String>(
                  value: 'Select Payment Method',
                  onChanged: (value) {
                    // Handle dropdown selection
                  },
                  items: ['Select Payment Method', 'Bkash', 'Sonali Bank']
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

            // Centered Button: Submit Feedback
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  if (selectedTicket + currentTicket > 600) {
                    Fluttertoast.showToast(
                        msg: 'You can not have more than 600 tickets at a time',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 1,
                        backgroundColor: Color.fromARGB(132, 244, 67, 54),
                        textColor: Colors.white,
                        fontSize: 16.0);
                    return;
                  }
                  ShurjopayRequestModel shurjopayRequestModel =
                      ShurjopayRequestModel(
                    configs: shurjopayConfigs,
                    currency: "BDT",
                    amount: 1.0 * (amount),
                    orderID: getRandomString(15),
                    discountAmount: 0,
                    discountPercentage: 0,
                    customerName: globel.userName,
                    customerPhoneNumber: globel.userPhone,
                    customerEmail: globel.userEmail,
                    customerAddress:
                        "Bangladesh University of Engineering and Technology",
                    customerCity: "Dhaka",
                    customerPostcode: "1000",
                    // Live: https://www.engine.shurjopayment.com/return_url
                    returnURL:
                        "https://www.sandbox.shurjopayment.com/return_url",
                    // Live: https://www.engine.shurjopayment.com/cancel_url
                    cancelURL:
                        "https://www.sandbox.shurjopayment.com/cancel_url",
                  );
                  shurjopayResponseModel = await shurjoPay.makePayment(
                    context: context,
                    shurjopayRequestModel: shurjopayRequestModel,
                  );
                  if (shurjopayResponseModel.status == true) {
                    try {
                      shurjopayVerificationModel =
                          await shurjoPay.verifyPayment(
                        orderID: shurjopayResponseModel.shurjopayOrderID!,
                      );
                      print(shurjopayVerificationModel.spCode);
                      print(shurjopayVerificationModel.spMessage);
                      if (shurjopayVerificationModel.spCode == "1000") {
                        print(shurjopayVerificationModel.bankTrxId);
                        context.loaderOverlay.show();
                        var r = await Requests.post(
                            globel.serverIp + 'purchaseTickets',
                            body: {
                              'method': 'shurjopay',
                              'trxid': shurjopayVerificationModel.bankTrxId,
                              'count': selectedTicket,
                            },
                            bodyEncoding: RequestBodyEncoding.FormURLEncoded);
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
                        context.loaderOverlay.hide();
                        getTicketInfo();
                        if (json['success'] == true) {
                          Fluttertoast.showToast(
                              msg: 'Payment Successful.',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Color.fromARGB(134, 48, 196, 3),
                              textColor: Colors.white,
                              fontSize: 16.0);
                        } else {
                          Fluttertoast.showToast(
                              msg: 'Payment Unsuccessful.',
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              timeInSecForIosWeb: 1,
                              backgroundColor: Color.fromARGB(132, 244, 67, 54),
                              textColor: Colors.white,
                              fontSize: 16.0);
                        }
                      } else if (shurjopayVerificationModel.spCode == "1005") {
                        print(shurjopayVerificationModel.bankStatus);
                        Fluttertoast.showToast(
                            msg: shurjopayVerificationModel.bankTrxId!,
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 1,
                            backgroundColor: Color.fromARGB(132, 244, 67, 54),
                            textColor: Colors.white,
                            fontSize: 16.0);
                      }
                    } catch (error) {
                      print(error.toString());
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF781B1B),
                ),
                child: Text(
                  'Confirm payment',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8), // Button text color
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
