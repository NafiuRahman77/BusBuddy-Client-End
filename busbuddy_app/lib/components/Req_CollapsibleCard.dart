import 'package:flutter/material.dart';

class Req_CollapsibleCard extends StatefulWidget {
  final String date;
  final String bus_type;
  final String location;
  final String subject;
  final String shortMessage;
  final String fullMessage;
  final String verdict;
  final String response;
  final String source;
  final String isApproved;
  final String driver;
  final String helper;
  final String bus;

  Req_CollapsibleCard({
    required this.subject,
    required this.shortMessage,
    required this.fullMessage,
    required this.date,
    required this.location,
    required this.bus_type,
    required this.source,
    this.verdict = "",
    this.response = "",
    required this.isApproved,
    required this.driver,
    required this.helper,
    required this.bus,
  });

  @override
  _ReqCollapsibleCardState createState() => _ReqCollapsibleCardState();
}

class _ReqCollapsibleCardState extends State<Req_CollapsibleCard> {
  bool isExpanded = false;
  String send_modify(String str) {
    print(str);
    if (str == "car")
      return "Car - 4 seats";
    else if (str == "mini")
      return "Mini Bus - 30 seats";
    else if (str == "normal")
      return "Bus - 52 seats";
    else if (str == "micro-8")
      return "Micro Bus - 8 seats";
    else if (str == "micro-12")
      return "Micro Bus - 12 seats";
    else if (str == "micro-15") return "Micro Bus - 15 seats";
    return "Bus - 52 seats";
  }

  Widget _buildResponseBox(String isApproved, String response) {
    Color textColor = isApproved == "Approved" ? Colors.green : Colors.red;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: textColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            response,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(
                child: SizedBox(),
              ),
              Text(
                isApproved == "Rejected"
                    ? 'Rejected By: ${widget.verdict}'
                    : 'Approved By: ${widget.verdict}',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (isApproved == "Approved") ...[
            SizedBox(height: 8.0),
            Text(
              'Driver: ${widget.driver}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              'Helper: ${widget.helper}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              'Bus: ${widget.bus}',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print(widget.isApproved);
    Color? backgroundColor;
    if (widget.isApproved != "") {
      bool hasResponse = widget.isApproved == "Approved" ? true : false;
      backgroundColor = hasResponse ? Colors.green[50] : Colors.red[50];
    } else
      backgroundColor = Colors.white;

    String conc_btype = '';
    List<String> stringList =
        widget.bus_type.replaceAll('{', '').replaceAll('}', '').split(',');
    for (String bus in stringList) {
      conc_btype += send_modify(bus) + ' ';
    }

    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.grey.withOpacity(0.5)),
      ),
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
                    widget.subject,
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
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place,
                            color: Colors.black,
                            size: 16,
                          ),
                          SizedBox(width: 5),
                          Text(
                            "Destination : " + widget.location,
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
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Padding(
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
                            "Source : " + widget.source,
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
                    padding: EdgeInsets.only(bottom: 4.0),
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            color: Colors.black,
                            size: 16,
                          ),
                          SizedBox(
                            width:
                                5, // Adjust the spacing between the Icon and Text as needed
                          ),
                          Text(
                            conc_btype,
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
                  if (widget.isApproved != "" &&
                      widget.isApproved == "Approved")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Request Status : Approved',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        _buildResponseBox(
                          "Approved",
                          widget.response,
                        ),
                      ],
                    )
                  else if (widget.isApproved == "")
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 10,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Response Pending',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.red,
                                size: 10,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Request Status : Rejected',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        _buildResponseBox(
                          "Rejected",
                          widget.response,
                        ),
                      ],
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
                        fontSize: 14,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
