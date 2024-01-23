import 'package:flutter/material.dart';

class Req_CollapsibleCard extends StatefulWidget {
  final String date;
  final String bus_type;
  final String location;
  final String subject;
  final String shortMessage;
  final String fullMessage;
  final String verdict;

  Req_CollapsibleCard({
    required this.subject,
    required this.shortMessage,
    required this.fullMessage,
    required this.date,
    required this.location,
    required this.bus_type,
    this.verdict = "",
  });

  @override
  _ReqCollapsibleCardState createState() => _ReqCollapsibleCardState();
}

class _ReqCollapsibleCardState extends State<Req_CollapsibleCard> {
  bool isExpanded = false;
  String send_modify(String str) {
    // JALAL BOL BACKEND E KI DISOS NAME :") , OI VAABE CNG KORISH EGULA .

    if (str == "single_decker")
      return "Single Decker";
    else if (str == "mini")
      return "Mini Bus";
    else if (str == "double_decker")
      return "Double Decker";
    else if (str == "micro") return "Micro Bus";
    return "Bus issue";
  }

  @override
  Widget build(BuildContext context) {
    bool hasResponse = widget.verdict.isNotEmpty;
    Color? backgroundColor = hasResponse ? Colors.green[50] : Colors.red[50];
    String conc_btype = '';
    List<String> stringList =
        widget.bus_type.replaceAll('{', '').replaceAll('}', '').split(',');
    for (String bus in stringList) {
      conc_btype += send_modify(bus) + ' ';
    }

    return Card(
      margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0.0),
      color: Colors.white, // Set the card background color to white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
            color: Colors.grey.withOpacity(0.3)), // Add a gray border
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
                padding: EdgeInsets.only(
                    top: 8.0,
                    bottom: 8.0), // Add space at the bottom of the title
                child: Padding(
                  padding: EdgeInsets.only(
                      left: 4.0), // Add left padding to the title
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
                    padding: EdgeInsets.only(
                        bottom: 4.0), // Add space at the bottom of the date
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 4.0), // Add left padding to the date
                      child: Text(
                        widget.date,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: 4.0), // Add space at the bottom of the date
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 4.0), // Add left padding to the date
                      child: Text(
                        widget.location,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: 4.0), // Add space at the bottom of the date
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: 4.0), // Add left padding to the date
                      child: Text(
                        conc_btype,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (hasResponse)
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
                                'Response Provided',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Text(
                            'Approved By : ${widget.verdict}',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
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
