import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:requests/requests.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../globel.dart' as globel;

class Notifications extends StatefulWidget {
  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {
  List<String> notificationTitle = [];
  List<String> notificationBody = [];
  List<String> notificationTime = [];
  List<String> notificationType = [];
  List<Map<String, dynamic>> notifications =
      []; // List to store notifications as objects

  Color evenColor = Color.fromARGB(255, 253, 221, 221);
  Color oddColor = Color(0xFFfaebeb);

  @override
  void initState() {
    super.initState();
    getNotifications();
  }

  Future<void> getNotifications() async {
    context.loaderOverlay.show();
    var prefs = await SharedPreferences.getInstance();
    List<String> notificationTitle_ = prefs.getStringList('noti_title') ?? [];
    List<String> notificationBody_ = prefs.getStringList('noti_body') ?? [];
    List<String> notificationTime_ = prefs.getStringList('noti_time') ?? [];
    List<String> notificationType_ = prefs.getStringList('noti_type') ?? [];

    var r = await Requests.post(globel.serverIp + 'getNotifications');
    var json = r.json();
    // print(json[0]['title']);

    for (int i = 0; i < json.length; i++) {
      notificationTitle_.add(json[i]['title']);
      notificationBody_.add(json[i]['body']);
      notificationTime_.add(json[i]['timestamp']);
      notificationType_.add(json[i]['type']);
    }

    setState(() {
      notificationTitle = notificationTitle_;
      notificationBody = notificationBody_;
      notificationTime = notificationTime_;
      notificationType = notificationType_;
    });

    List<Map<String, dynamic>> notifications_ = [];

    print("lol" + notificationTitle.length.toString());

    for (int i = 0; i < notificationTitle.length; i++) {
      Map<String, dynamic> notif = {};

      notif['title'] = notificationTitle[i];
      notif['body'] = notificationBody[i];
      notif['time'] = notificationTime[i];
      notif['type'] = notificationType[i];

      notifications_.add(notif);
    }

    // print(notifications);

    // Sort notifications based on time
    notifications_.sort((a, b) =>
        DateTime.parse(a['time']).compareTo(DateTime.parse(b['time'])));

    notifications_ = notifications_.reversed.toList();

    for (int i = 0; i < notifications_.length; i++) {
      DateTime time = DateTime.parse(notifications_[i]['time']);
      String formattedTime = DateFormat("dd MMM h:mm a").format(time);
      notifications_[i]['time'] = formattedTime;
    }

    setState(() {
      notifications = notifications_;
    });

    print(notificationTitle.length);
    context.loaderOverlay.hide();
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
    return LoaderOverlay(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 0,
        ),
        body: ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification_title = notifications[index]['title'];
            final notification_body = notifications[index]['body'];
            final notification_time = notifications[index]['time'];
            //final notification_type = notificationType[index];
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
                color: index.isEven
                    ? Color.fromARGB(255, 253, 229, 229)
                    : Color(0xFFfaebeb),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    4, 15, 5, 15), // Adjust padding as needed
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                        backgroundColor: Colors.transparent,
                        radius: 30,
                        child: _buildNotificationIcon(
                            notifications[index]['type'])),
                    SizedBox(width: 5.0), // Add space between avatar and text
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
      ),
    );
  }
}
