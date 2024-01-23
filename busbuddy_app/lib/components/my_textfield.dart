import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final controller;
  final String hintText;
  final bool obscureText;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: TextField(
        style: TextStyle(color: Colors.white),
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          // Remove the border
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white), // Underline color
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white), // Underline color
          ),
          fillColor: Colors.transparent,
          // Set background to transparent
          filled: true,
          hintText: hintText,
          hintStyle: TextStyle(color: Color.fromARGB(160, 255, 255, 255)),
        ),
      ),
    );
  }
}
