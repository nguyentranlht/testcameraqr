import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  MyApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}