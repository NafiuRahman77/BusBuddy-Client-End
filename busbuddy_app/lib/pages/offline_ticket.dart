import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../globel.dart' as globel;

class OfflineTicketQR extends StatefulWidget {
  @override
  _OfflineTicketQRState createState() => _OfflineTicketQRState();
}

class _OfflineTicketQRState extends State<OfflineTicketQR> {
  List<String> ticketIds = [];
  List<String> ticketIdsShortened = [];
  int currentPageIndex = 0;
  late PageController _pageController; // Add this line

  @override
  void initState() {
    super.initState();
    // getTicketInfo();

    getTicketInfo();
    _pageController =
        PageController(initialPage: currentPageIndex); // Add this line
  }

  Future<void> getTicketInfo() async {
    // get from shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      ticketIds = prefs.getStringList('ticketIds') ?? [];
      ticketIdsShortened = ticketIds.map((e) => e.substring(0, 5)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ticketIds.isEmpty
        ? Scaffold(
            appBar: AppBar(
              // TRY THIS: Try changing the color here to a specific color (to
              // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
              // change color while the other colors stay the same.
              backgroundColor: Color(0xFF781B1B),
              // Here we take the value from the MyHomePage object that was created by
              // the App.build method, and use it to set our appbar title.
              foregroundColor: Colors.white,
              title: Text('Offline Tickets'),
            ),
            body: Text('No tickets found'))
        : Scaffold(
            appBar: AppBar(
              // TRY THIS: Try changing the color here to a specific color (to
              // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
              // change color while the other colors stay the same.
              backgroundColor: Color(0xFF781B1B),
              // Here we take the value from the MyHomePage object that was created by
              // the App.build method, and use it to set our appbar title.
              foregroundColor: Colors.white,
              title: Text('Offline Tickets'),
            ),
            body: Stack(
              children: [
                PageView.builder(
                  controller: _pageController, // Pass the page controller
                  itemCount: ticketIds.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Center(
                      child: QrImageView(
                        data: ticketIds[index],
                        version: QrVersions.auto,
                        size: 350.0,
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: () {
                            if (currentPageIndex > 0) {
                              _pageController.previousPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            }
                          },
                        ),
                        Text(
                          'Trip ID: ${ticketIdsShortened[currentPageIndex]}',
                          style: TextStyle(fontSize: 18),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward),
                          onPressed: () {
                            if (currentPageIndex < ticketIds.length - 1) {
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
