import 'package:flutter/material.dart';

class DriverHelperInfo extends StatelessWidget {
  final String title;
  final String name;
  final String phone;

  const DriverHelperInfo({
    Key? key,
    required this.title,
    required this.name,
    required this.phone,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.grey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: Colors.red,
              ),
              SizedBox(width: 5),
              Text(
                'Name: $name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 18,
                color: Colors.black87,
              ),
              SizedBox(width: 5),
              Text(
                'Phone: $phone',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              // Implement call functionality
            },
            child: Text('Call Now'),
          ),
        ],
      ),
    );
  }
}
