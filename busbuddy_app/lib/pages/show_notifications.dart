import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Notifications extends StatefulWidget {
  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  // JALAL BACKEND THEKE PATHABE
  List<Map<String, dynamic>> notifications = [
    {
      'title': 'Track a Bus',
      'message': 'Your requested bus is 5 mins away from your location.',
      'date': '2024-02-07',
      'icon': Icons.directions_bus,
    },
    {
      'title': 'Calendar Schedule',
      'message': 'The bus schedule for tomorrow has been changed.',
      'date': '2024-02-07',
      'icon': Icons.event,
    },
    {
      'title': 'Ticket Purchase',
      'message':
          'Your ticket purchase has been confirmed. Please check for the ticket details.',
      'date': '2024-02-07',
      'icon': Icons.confirmation_number,
    },
  ];
  Color evenColor = Color(0xFFffd5d6);
  Color oddColor = Color(0xFFfaebeb);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF781B1B),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  //JALAL BACKEND LEKHO
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF781B1B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                child: Text('All', style: TextStyle(color: Colors.white)),
              ),
              ElevatedButton(
                onPressed: () {
                  // JALAL BACKEND LEKHO
                },
                style: ElevatedButton.styleFrom(
                    primary: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                        EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                child: Text('Unread', style: TextStyle(color: Colors.red)),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: index.isEven ? evenColor : oddColor,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 30,
                    child: Icon(
                      notification['icon'],
                      size: 30,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification['title'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.0,
                                color: Colors.black, // Text color
                              ),
                            ),
                            Text(
                              DateFormat('yyyy-MM-dd').format(
                                DateTime.parse(notification['date'] ?? ''),
                              ),
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.black, // Text color
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          notification['message'] ?? '',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.black, // Text color
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
