import 'package:flutter/material.dart';
import '../components/CustomCard.dart';

class RouteTimeMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          Container(
            color: Colors.white, // Background color for the card
            child: Center(
              child: Container(
                width: 300.0,
                child: Card(
                  elevation: 20,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 50.0,
                          backgroundImage:
                              AssetImage('lib/sjb/images/logobusbuddy-1.png'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mohammadpur-1',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black, // Text color
                          ),
                        ),
                        SizedBox(height: 20),
                        CircleWidget(
                            text1: 'Mohammadpur', text2: '6:30 AM', x: 1),
                        SizedBox(height: 10),
                        CircleWidget(
                            text1: 'Dhanmondi', text2: '6:40 AM', x: 1),
                        SizedBox(height: 10),
                        CircleWidget(text1: 'BUET', text2: '6:50 AM', x: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 30,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 16.0), // Adjust the padding as needed
            child: Image(
              fit: BoxFit.cover, // Image fills the entire width
              image: AssetImage('lib/images/map.PNG'),
            ),
          ),
        ],
      ),
    );
  }
}
