import 'dart:ui';
import 'package:flutter/material.dart';

class AuthCardWide extends StatefulWidget {
  final Widget formSection;

  const AuthCardWide({required this.formSection, Key? key}) : super(key: key);

  @override
  _AuthCardWideState createState() => _AuthCardWideState();
}

class _AuthCardWideState extends State<AuthCardWide> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        transform: _isHovered ? Matrix4.translationValues(0, -5, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isHovered
              ? [BoxShadow(color: Colors.black38, blurRadius: 20, spreadRadius: 4)]
              : [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 2)],
        ),
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: 600, // Wide layout
            height: 300, // Shorter height
            child: Row(
              children: [
                // Left Side - Welcome Message
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[100],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        bottomLeft: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "Welcome to VersaTale!",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                // Right Side - Login Form
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: widget.formSection,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
