import 'package:flutter/material.dart';

class CollapsibleCard extends StatefulWidget {
  final String subject;
  final String shortMessage;
  final String fullMessage;
  final String responseMessage;
  final String date;
  final String route;

  CollapsibleCard({
    required this.subject,
    required this.shortMessage,
    required this.fullMessage,
    required this.date,
    required this.route,
    this.responseMessage = "",
  });

  @override
  _CollapsibleCardState createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  bool isExpanded = false;
  String send_modify(String str) {
    if (str == "other")
      return "Others";
    else if (str == "bus")
      return "Bus Issue";
    else if (str == "driver")
      return "Bus Driver";
    else if (str == "staff") return "Bus Staff";
    return "Bus issue";
  }

  @override
  Widget build(BuildContext context) {
    print(widget.responseMessage);
    bool hasResponse = widget.responseMessage.isNotEmpty;
    Color? backgroundColor = hasResponse ? Colors.green[50] : Colors.red[50];
    String concatenatedSubjects = '';
    List<String> stringList =
        widget.subject.replaceAll('{', '').replaceAll('}', '').split(',');
    for (String subject in stringList) {
      concatenatedSubjects += send_modify(subject) + ' ';
    }
    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          setState(() {
            isExpanded = !isExpanded;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Text(
                    concatenatedSubjects,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF781B1B),
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            color: Colors.black,
                            size: 16,
                          ),
                          SizedBox(width: 5),
                          Text(
                            widget.date,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.black,
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          widget.route,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fullMessage,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        if (hasResponse)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      color: Color(0xFF781B1B)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Admin Response',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF781B1B),
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Color(0xFF781B1B), width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  widget.responseMessage,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      widget.shortMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
