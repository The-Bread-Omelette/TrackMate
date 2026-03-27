// import 'dart:async';
// import 'dart:ui';
// import 'package:flutter/foundation.dart';
// // import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:pedometer/pedometer.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// Future<void> initBackgroundService() async {
//   if (kIsWeb) return;
//   final service = FlutterBackgroundService();
//   await service.configure(
//     androidConfiguration: AndroidConfiguration(
//       onStart: onStart,
//       isForegroundMode: true,
//       autoStart: true,
//       autoStartOnBoot: true,
//     ),
//     iosConfiguration: IosConfiguration(
//       autoStart: true,
//       onForeground: onStart,
//       onBackground: onIosBackground,
//     ),
//   );
// }
//
// @pragma('vm:entry-point')
// Future<bool> onIosBackground(ServiceInstance service) async => true;
//
// @pragma('vm:entry-point')
// void onStart(ServiceInstance service) {
//   DartPluginRegistrant.ensureInitialized();
//   int sessionStart = 0;
//   bool first = true;
//
//   Pedometer.stepCountStream.listen((event) {
//     if (first) {
//       sessionStart = event.steps;
//       first = false;
//     }
//     service.invoke('steps', {'steps': event.steps - sessionStart});
//   });
// }
//
// class PedometerService {
//   final _controller = StreamController<int>.broadcast();
//   Stream<int> get steps => _controller.stream;
//
//   Future<void> start() async {
//     if (kIsWeb) return;
//     await Permission.activityRecognition.request();
//     final service = FlutterBackgroundService();
//     await service.startService();
//     service.on('steps').listen((data) {
//       if (data != null) {
//         _controller.add((data['steps'] as num).toInt());
//       }
//     });
//   }
//
//   void dispose() => _controller.close();
// }