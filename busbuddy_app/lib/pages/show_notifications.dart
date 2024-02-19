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
  List<String> notificationType = [];

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
    List<String> notificationType_ = prefs.getStringList('noti_type') ?? [];

    for (int i = 0; i < notificationTime_.length; i++) {
      DateTime time = DateTime.parse(notificationTime_[i]);
      String formattedTime = DateFormat.jm().format(time);
      notificationTime_[i] = formattedTime;
    }

    print(notificationType_.length);

    setState(() {
      notificationTitle = notificationTitle_;
      notificationBody = notificationBody_;
      notificationTime = notificationTime_;
      notificationType = notificationType_;
    });
  }

  Widget _buildNotificationIcon(String notificationType) {
    IconData iconData;
    Color iconColor = Colors.black;

    switch (notificationType) {
      case 'route_started':
      case 'helper_trip_start':
      case 'helper_trip_end':
        iconData = Icons.directions_bus;
        break;
      case 'station_approaching':
      case 'ticket_low_warning':
        iconData = Icons.warning;
        break;
      case 'ticket_used':
        iconData = Icons.confirmation_number;
        break;
      case 'personal':
        iconData = Icons.person;
        break;
      case 'broadcast':
        iconData = Icons.broadcast_on_home;
        break;
      default:
        iconData = Icons.notifications_active;
    }

    return Icon(
      iconData,
      size: 30,
      color: iconColor,
    );
  }

  @override
  void dispose() {
    super.dispose();
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
          //final notification_type = notificationType[index];
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
                      child: _buildNotificationIcon(notificationType[index])),
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
