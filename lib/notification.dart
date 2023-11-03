import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FlutterLocalNotification {
  FlutterLocalNotification._();

  static FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static init() async {
    AndroidInitializationSettings androidInitializationSettings =
        const AndroidInitializationSettings('mipmap/ic_launcher');

    DarwinInitializationSettings iosInitializationSettings =
        const DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static requestNotificationPermission() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showNotification(String? title, String? content) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('channel id', 'channel name',
            channelDescription: 'channel description',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: false);

    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: DarwinNotificationDetails(badgeNumber: 1));

    // 5초 후에 알림을 보냅니다.
    Future.delayed(const Duration(seconds: 5), () async {
      await flutterLocalNotificationsPlugin.show(
          0, title, content, notificationDetails);
    });

    // await flutterLocalNotificationsPlugin.show(
    //     0, title, content, notificationDetails);
  }
}
