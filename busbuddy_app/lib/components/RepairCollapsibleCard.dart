import 'package:flutter/material.dart';

class RepairCollapsibleCard extends StatefulWidget {
  final String bus;
  final String parts;
  final String request_description;
  final String repair_description;
  final String responseMessage;
  final String date;

  RepairCollapsibleCard({
    required this.bus,
    required this.parts,
    required this.request_description,
    required this.repair_description,
    required this.date,
    this.responseMessage = "",
  });

  @override
  _RepairCollapsibleCardState createState() => _RepairCollapsibleCardState();
}

class _RepairCollapsibleCardState extends State<RepairCollapsibleCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    print(widget.responseMessage);
    bool hasResponse = widget.responseMessage.isNotEmpty;
    Color? backgroundColor = hasResponse ? Colors.green[50] : Colors.red[50];

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
                    widget.bus,
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
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8.0, left: 15.0),
              child: Padding(
                padding: EdgeInsets.only(left: 4.0),
                child: Text(
                  widget.parts,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF781B1B),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            isExpanded
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request_description,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          widget.repair_description,
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
                                    fontSize: 14,
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
                      widget.request_description.split(' ').length > 20
                          ? widget.request_description
                                  .split(' ')
                                  .sublist(0, 20)
                                  .join(' ') +
                              '...'
                          : widget.request_description,
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
