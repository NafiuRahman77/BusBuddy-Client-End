import 'package:flutter/material.dart';
import 'package:requests/requests.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:intl/intl.dart';
import '../../globel.dart' as globel;

class TicketHistory extends StatefulWidget {
  @override
  _TicketHistoryState createState() => _TicketHistoryState();
}

class _TicketHistoryState extends State<TicketHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> routes = [
    'Route 1',
    'Route 2',
    // Add more route entries here as String
  ];

  List<String> ticketAmountList = [];
  List<String> usageDateList = [];
  List<String> usageQuantityList = [];
  List<String> purchaseDateList = [];

  List<String> usageRouteList = [];
  List<String> usageTripIDList = [];
  List<String> usageTimeList = [];
  List<String> usageDirectionList = [];
  List<String> usageScannedByList = [];
  // Add more ticket amounts and dates as needed

  @override
  void initState() {
    super.initState();
    onPageMount();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> onPageMount() async {
    context.loaderOverlay.show();
    var r = await Requests.post(globel.serverIp + 'getUserPurchaseHistory');

    r.raiseForStatus();
    dynamic json = r.json();

    setState(() {
      for (int i = 0; i < json.length; i++) {
        purchaseDateList.add(json[i]['timestamp'].toString());
        ticketAmountList.add(json[i]['quantity'].toString());
      }
      for (int i = 0; i < purchaseDateList.length; i++) {
        DateTime dateTime = DateTime.parse(purchaseDateList[i]);
        // Format the time in AM/PM format without seconds
        String formattedDate = "${dateTime.toLocal()}".split(" ")[0];
        String formattedTime = DateFormat('h:mma').format(dateTime);
        purchaseDateList[i] = formattedDate + "  " + formattedTime;
      }
    });

    // reverse the list to show the latest purchase first
    purchaseDateList = purchaseDateList.reversed.toList();
    ticketAmountList = ticketAmountList.reversed.toList();

    var r1 = await Requests.post(globel.serverIp + 'getTicketUsageHistory');
    dynamic json1 = r1.json();

    setState(() {
      for (int i = 0; i < json1.length; i++) {
        usageRouteList.add(json1[i]['route'].toString());
        usageTripIDList.add(json1[i]['trip_id'].toString());
        usageTimeList.add(json1[i]['start_timestamp'].toString());
        usageDirectionList.add(json1[i]['travel_direction'].toString());
        usageScannedByList.add(json1[i]['scanned_by'].toString());
      }
      for (int i = 0; i < usageTimeList.length; i++) {
        usageTimeList[i] = formatDateString(usageTimeList[i]);
      }
    });

    print("in ticket history");
    print(json);

    context.loaderOverlay.hide();
  }

  String formatDateString(String dateTimeString) {
    // Parse the string into a DateTime object
    DateTime dateTime = DateTime.parse(dateTimeString);

    // Format the date
    String formattedDate = DateFormat('yyyy-MM-dd').format(dateTime);

    // Format the time
    String formattedTime = DateFormat('h:mm a').format(dateTime);

    return '$formattedDate, $formattedTime';
  }

  @override
  Widget build(BuildContext context) {
    print(purchaseDateList);
    print(ticketAmountList);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: null,
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Purchase'),
                  Tab(text: 'Usage'),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Purchase Tab Content

            ListView.builder(
              itemCount: purchaseDateList.length,
              itemBuilder: (BuildContext context, int index) {
                final ticketAmount = ticketAmountList[index];
                final date = purchaseDateList[index];
                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time of purchase:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Ticket Quantity:  ${ticketAmount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Usage Tab Content (Similar code as above)
            ListView.builder(
              itemCount: usageTripIDList.length,
              itemBuilder: (BuildContext context, int index) {
                final route = usageRouteList[index];
                final tripID = usageTripIDList[index];
                final time = usageTimeList[index];
                final direction = usageDirectionList[index];
                final scannedBy = usageScannedByList[index];

                return Container(
                  margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Column 1: Route, Trip ID, Time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Route : ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                                TextSpan(
                                  text: route,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Trip ID : ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.0,
                                  ),
                                ),
                                TextSpan(
                                  text: tripID,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Scanned By :',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.0,
                            ),
                          ),
                          Text(
                            scannedBy,
                            style: TextStyle(
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                      // Column 2: Direction, Scanned By
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // Conditionally show icon based on direction
                              if (direction.toLowerCase() == 'from_buet')
                                Icon(Icons.arrow_upward,
                                    color: Colors.green, size: 32.0),
                              if (direction.toLowerCase() != 'from_buet')
                                Icon(Icons.arrow_downward,
                                    color: Colors.red, size: 32.0),
                            ],
                          ),
                          // Place the Time text beneath the arrow icon
                          SizedBox(
                              height:
                                  30.0), // Add some space between the arrow and the time
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontStyle:
                                  FontStyle.italic, // Make the time italic
                              color: Colors
                                  .grey, // Change the color of the time text
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
