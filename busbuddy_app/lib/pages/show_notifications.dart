import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Notifications extends StatefulWidget {
  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<String> notificationTitle = [];
  List<String> notificationBody = [];
  List<String> notificationTime = [];

  Color evenColor = Color.fromARGB(255, 253, 221, 221);
  Color oddColor = Color(0xFFfaebeb);

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  Future<void> getNotifications() async {
    var prefs = await SharedPreferences.getInstance();
    List<String> notificationTitle_ = prefs.getStringList('noti_title') ?? [];
    List<String> notificationBody_ = prefs.getStringList('noti_body') ?? [];
    List<String> notificationTime_ = prefs.getStringList('noti_time') ?? [];
    setState(() {
      notificationTitle = notificationTitle_;
      notificationBody = notificationBody_;
      notificationTime = notificationTime_;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
      ),
      body: ListView.builder(
        itemCount: notificationTitle.length,
        itemBuilder: (context, index) {
          final notification_title = notificationTitle[index];
          final notification_body = notificationBody[index];
          final notification_time = notificationTime[index];
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(0),
              color: index.isEven
                  ? Color.fromARGB(255, 253, 229, 229)
                  : Color(0xFFfaebeb),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.0), // Adjust padding as needed
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 30,
                    child: Icon(
                      Icons.notifications_active,
                      size: 30,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 10.0), // Add space between avatar and text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification_title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.0,
                                color: Colors.black, // Text color
                              ),
                            ),
                            Spacer(), // Pushes the time to the right corner
                            Text(
                              notification_time ?? '',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontStyle: FontStyle.italic, // Set to italic
                                color: Colors.black, // Text color
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          notification_body ?? '',
                          style: TextStyle(
                            fontSize: 12.0,
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
