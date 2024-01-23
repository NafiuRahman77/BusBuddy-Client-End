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
  List<String> usageDateList = ['2023-09-16', '2023-09-17'];
  List<String> usageQuantityList = ['1', '1'];
  List<String> purchaseDateList = [];
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
    context.loaderOverlay.hide();

    // print(purchaseDateList);
    // print(ticketAmountList);

    //print(r.content());
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
              itemCount: usageDateList.length,
              itemBuilder: (BuildContext context, int index) {
                final ticketAmount = usageQuantityList[index];
                final date = usageDateList[index];
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
                            'Date:',
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
          ],
        ),
      ),
    );
  }
}
