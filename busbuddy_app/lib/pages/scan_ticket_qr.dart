import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../../globel.dart' as globel;

class ScanTicketQR extends StatefulWidget {
  const ScanTicketQR({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ScanTicketQRState();
}

class _ScanTicketQRState extends State<ScanTicketQR> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  String? ticket_id = "";

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF7B1B1B),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  // if (result != null)
                  //   Text(
                  //       'Barcode Type: ${describeEnum(result!.format)}   Data: ${result!.code}')
                  // else
                  //   const Text('Scan a code'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Container(
                      //   margin: const EdgeInsets.all(8),
                      //   child: ElevatedButton(
                      //     onPressed: () async {
                      //       await controller?.pauseCamera();
                      //     },
                      //     child: const Text('pause',
                      //         style: TextStyle(fontSize: 20)),
                      //   ),
                      // ),
                      // Container(
                      //   margin: const EdgeInsets.all(8),
                      //   child: ElevatedButton(
                      //     onPressed: () async {
                      //       await controller?.resumeCamera();
                      //     },
                      //     child: const Text('resume',
                      //         style: TextStyle(fontSize: 20)),
                      //   ),
                      // ),
                      // show the number of passengers
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Passenger: $passenger_count',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
                        ),
                      )
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Color(0xFFFFFFFF).withOpacity(0.7)),
                              shape: MaterialStateProperty.all<
                                  RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                ),
                              ),
                              //set size
                              minimumSize:
                                  MaterialStateProperty.all<Size>(Size(35, 35)),
                            ),
                            onPressed: () async {
                              await controller?.toggleFlash();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getFlashStatus(),
                              builder: (context, snapshot) {
                                return Icon(
                                    // flash icon
                                    snapshot.data == true
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    // You can adjust the icon size and color here
                                    size: 16.0,
                                    color: Color(0xFF7B1B1B));
                              },
                            )),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(
                                  Color(0xFFFFFFFF).withOpacity(0.7)),
                              shape: MaterialStateProperty.all<
                                  RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18.0),
                                ),
                              ),
                              //set size
                              minimumSize:
                                  MaterialStateProperty.all<Size>(Size(35, 35)),
                            ),
                            onPressed: () async {
                              await controller?.flipCamera();
                              setState(() {});
                            },
                            child: FutureBuilder(
                              future: controller?.getCameraInfo(),
                              builder: (context, snapshot) {
                                if (snapshot.data != null) {
                                  return Icon(
                                      // switch camera icon
                                      Icons.flip_camera_ios,
                                      // You can adjust the icon size and color here
                                      size: 16.0,
                                      color: Color(0xFF7B1B1B));
                                } else {
                                  return CircularProgressIndicator(); // Show a loading indicator
                                }
                              },
                            )),
                      )
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    List<String?> scanned_ids = [];

    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      if (!scanned_ids.contains(scanData.code)) {
        setState(() {
          ticket_id = scanData.code;
          scanTicket();
          scanned_ids.add(scanData.code);
          //pause the camera
          // controller.pauseCamera();
        });
      }
    });
  }

  String passenger_count = "";

  Future<void> scanTicket() async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'staffScanTicket',
        body: {
          'ticket_id': ticket_id,
        },
        bodyEncoding: RequestBodyEncoding.JSON);

    r.raiseForStatus();
    dynamic json = r.json();

    if (json['success'] == true) {
      Fluttertoast.showToast(
          msg:
              'Ticket from Student#${json['student_id']} Scanned Successfully.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(118, 76, 175, 80),
          textColor: Colors.white,
          fontSize: 16.0);
      setState(() {
        passenger_count = json['passenger_count'].toString();
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

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('no Permission')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    onQrScannerMount();
  }

  Future<void> onQrScannerMount() async {
    context.loaderOverlay.show();
    var r4 = await Requests.post(globel.serverIp + 'checkStaffRunningTrip');
    print("hello bus stff");
    r4.raiseForStatus();
    dynamic rt = r4.json();
    if (rt['success']) {
      globel.runningTripId = rt['id'];
      setState(() {
        passenger_count = rt['passenger_count'].toString();
      });
      context.loaderOverlay.hide();
      return;
    } else {
      GoRouter.of(context).go('/show_profile');
      Fluttertoast.showToast(
          msg: 'Please start a trip first.',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Color.fromARGB(118, 185, 26, 5),
          textColor: Colors.white,
          fontSize: 16.0);
      context.loaderOverlay.hide();
      return;
    }
  }
}
