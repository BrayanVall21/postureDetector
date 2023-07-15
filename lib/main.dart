import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:sensors_plus/sensors_plus.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de postura',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Detector de postura'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _postureStatus = 'No detectado';
  String _accelerometerValues = 'No detectado';
  String _gyroscopeValues = 'No detectado';
  late StreamSubscription _accelerometerSubscription;
  late StreamSubscription _gyroscopeSubscription;
  late Timer _timer;

  int _goodPostureCount = 0;
  int _badPostureCount = 0;

  @override
  void initState() {
    super.initState();
    _getUserId();
    _listenToSensors();
  }

  @override
  void dispose() {
    _stopListeningToSensors();
    super.dispose();
  }

  void _getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId == null) {
      userId = Uuid().v4();
      await prefs.setString('userId', userId);
    }
  }

  void _listenToSensors() {
    _accelerometerSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
          setState(() {
            _accelerometerValues =
            'X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)}';
            _postureStatus = _calculatePostureStatus(event);
          });
        });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscopeValues =
        'X: ${event.x.toStringAsFixed(2)}, Y: ${event.y.toStringAsFixed(2)}, Z: ${event.z.toStringAsFixed(2)}';
      });
    });

    _timer = Timer.periodic(Duration(minutes: 1), (Timer t) {
      _registerPosture();
    });
  }

  String _calculatePostureStatus(AccelerometerEvent event) {
    double x = event.x;
    double y = event.y;
    double z = event.z;
    double angle = atan(z / sqrt(pow(x, 2) + pow(y, 2))) * (180 / pi);
    if (angle.abs() < 10) {
      _goodPostureCount++;
      return 'Buena postura';
    } else {
      _badPostureCount++;
      if (angle > 0) {
        return 'Inclínese hacia adelante';
      } else {
        return 'Inclínese hacia atrás';
      }
    }
  }

  void _registerPosture() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId != null) {
      DocumentReference postureRef =
      FirebaseFirestore.instance.collection('posture').doc(userId);
      postureRef.set({
        'good_posture_count': _goodPostureCount,
        'bad_posture_count': _badPostureCount,
      });
    }
  }

  void _stopListeningToSensors() {
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Estado de la postura:',
            ),
            Text(
              _postureStatus,
              style: Theme.of(context).textTheme.headline4,
            ),
            const SizedBox(height: 32),
            Text(
              'Valores del acelerómetro:',
            ),
            Text(
              _accelerometerValues,
            ),
            const SizedBox(height: 32),
            Text(
              'Valores del giroscopio:',
            ),
            Text(
              _gyroscopeValues,
            ),
          ],
        ),
      ),
    );
  }
}