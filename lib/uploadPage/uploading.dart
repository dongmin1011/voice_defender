import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // extendBodyBehindAppBar: true, //영역을 확장하여 적용
        // backgroundColor: Colors.grey[200],
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.black54, size: 25),

          title: Image.asset(
            "assets/data/logo.png",
            width: 200,
          ),
          toolbarHeight: 150,
          centerTitle: true,
          elevation: 0,
          // shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
          backgroundColor: Colors.transparent,
        ),
        bottomNavigationBar: CurvedNavigationBar(
            backgroundColor: Colors.white,
            color: Colors.blueAccent.shade200,
            animationDuration: const Duration(milliseconds: 300),
            animationCurve: Curves.decelerate,
            items: [Icon(Icons.home), Icon(Icons.settings)]),
        // drawer: Container(),
        body: Container());
  }
}
