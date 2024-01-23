import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0xFF781B1B), // Set the background color to red
      leading: Builder(
        builder: (context) {
          return IconButton(
            icon: Icon(Icons.menu), // Use the hamburger icon
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Open the drawer when the icon is tapped
            },
          );
        },
      ),
      actions: [
        Row(
          children: [
            Text(
              'Sojib',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8.0), // Add some spacing between text and image
            CircleAvatar(
              radius: 20.0, // Adjust the radius for the smaller image
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('lib/images/image-15.png'), // Use the same local image
            ),
          ],
        ),

      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
