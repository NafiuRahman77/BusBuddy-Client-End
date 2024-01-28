import 'package:flutter/material.dart';

class MyTextField extends StatefulWidget {
  final controller;
  final String hintText;
  bool obscureText;
  bool showicon = true ; 
  bool ispass; 

  MyTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.ispass,
  }) : super(key: key);

  @override
  State<MyTextField> createState() => MyTextState();
}

class MyTextState extends State<MyTextField> {
  @override
  void initState() {
    super.initState();
    // Add any initialization logic if needed
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: TextField(
        style: TextStyle(color: Colors.white),
        controller: widget.controller,
        obscureText: widget.obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          fillColor: Colors.transparent,
          filled: true,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Color.fromARGB(160, 255, 255, 255)),
          suffixIcon: widget.ispass? IconButton(icon: Icon(widget.showicon? Icons.visibility:Icons.visibility_off),onPressed: (){
            setState(() {
              widget.obscureText = !widget.obscureText ; 
              widget.showicon = !widget.showicon ; 
            });
          },):null 
        ),
      ),
    );
  }
}
