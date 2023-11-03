import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_defender/resultPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dio/dio.dart';
import 'loadingWidget.dart';
import 'notification.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  FlutterLocalNotification.init();

  Future.delayed(const Duration(seconds: 3),
      FlutterLocalNotification.requestNotificationPermission());

  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will be executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,

      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'AWESOME SERVICE',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will be executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

class CallListenerWidget extends StatefulWidget {
  @override
  _CallListenerWidgetState createState() => _CallListenerWidgetState();
}

class _CallListenerWidgetState extends State<CallListenerWidget> {
  static const platform = MethodChannel('com.example.voice_defender/call');
  bool _duringCall = false;

  @override
  void initState() async {
    super.initState();

    _requestPermission();

    _startListening();
  }

  Future<void> _getDummisData() async {
    Dio dio = Dio(
      BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
    );

    String url = '/api/ai/analysis-test';
    Response res = await dio.post(url);

    if (res.statusCode == 200) {
      print(res.data);

      if (res.data['isVoicePhishing']) {
        FlutterLocalNotification.showNotification(
            '위험', '방금 통화는 보이스 피싱으로 의심됩니다...');
      }
    }
  }

  Future<void> _uploadAudioFile() async {
    Directory dir = Directory('/storage/emulated/0/Recordings/Call/');
    List<FileSystemEntity> fileList = await dir.list().toList();
    if (fileList.isNotEmpty) {
      fileList.sort((a, b) => File(b.path)
          .statSync()
          .modified
          .compareTo(File(a.path).statSync().modified));
    }

    String? latestFilePath = fileList.first.path;
    Dio dio = Dio(
      BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
    );

    String url = '/api/ai/analysis';
    String ext = latestFilePath.split('.').last;
    String filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';

    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        latestFilePath,
        filename: filename,
      ),
    });

    Response res = await dio.post(url, data: formData);

    if (res.statusCode == 200) {
      print('File upload successful');
      print(res.data);

      print('isDeepVoice >> ' + res.data['isDeepVoice'].toString());
      print('isDeepVoice >> ' + res.data['isVoicePhishing'].toString());

      if (res.data['isVoicePhishing'] == true) {
        print('피싱 의심!!');
        FlutterLocalNotification.showNotification(
            '위험', '방금 통화는 보이스 피싱으로 의심됩니다...');
      }
    } else
      print('File upload failed');
  }

  Future<void> _requestPermission() async {
    await Permission.phone.request();
  }

  Future<void> _startListening() async {
    platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onCallEnded':
          print('>>>>>>>>>>>>>>>>>>>>>>>>> END <<<');
          if (_duringCall) {
            print('>>>>>>>>>>>> Upload <<<<<<<<<<<');
            _uploadAudioFile();
          }
          setState(() {
            _duringCall = false;
          });
          break;
        case 'onCallStarted':
          print('>>> Start <<<<<<<<<<<<<<<<<<<<<<<');
          setState(() {
            _duringCall = true;
          });
          break;
        default:
          throw MissingPluginException('notImplemented');
      }
    });

    try {
      await platform.invokeMethod('startListening');
    } on PlatformException catch (e) {
      print('Failed to start listening: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  SharedPreferences preferences = await SharedPreferences.getInstance();

  runApp(CallListenerWidget());

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List pageViewItem;
  late PageController _controller;
  static dynamic currentPageValue = 0.0;

  static const platform = MethodChannel('com.example.voice_defender/call');
  String _callStatus = 'Unknown';

  @override
  void initState() {
    //page컨트롤러 초기화
    super.initState();

    _requestPermission();
    _startListening();

    // _currentIndex = 0;
    _controller = PageController(initialPage: -1, viewportFraction: 0.8);
    _controller.addListener(() {
      setState(() {
        currentPageValue = _controller.page;
      });
    });
  }

  Future<void> _requestPermission() async {
    await Permission.phone.request();
    await Permission.audio.request();
    await Permission.notification.request();
  }

  Future<void> _uploadAudioFile() async {
    Directory dir = Directory('/storage/emulated/0/Recordings/Call/');
    List<FileSystemEntity> fileList = await dir.list().toList();

    if (fileList.isNotEmpty) {
      fileList.sort((a, b) => File(b.path)
          .statSync()
          .modified
          .compareTo(File(a.path).statSync().modified));
    }

    String? latestFilePath = fileList.first.path;
    Dio dio = Dio(
      BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
    );

    String url = '/api/ai/analysis';
    // String url = '/api/ai/analysis-test'; //get dummis data url
    String ext = latestFilePath.split('.').last;
    String filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';

    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        latestFilePath,
        filename: filename,
      ),
    });

    Response res = await dio.post(url, data: formData);

    if (res.statusCode == 200) {
      print('File upload successful');
      print(res.data);

      print('isDeepVoice >> ' + res.data['isDeepVoice'].toString());
      print('isDeepVoice >> ' + res.data['isVoicePhishing'].toString());

      if (res.data['isVoicePhishing'] == true) {
        print('피싱 의심!!');
        FlutterLocalNotification.showNotification(
            '위험', '방금 통화는 보이스 피싱으로 의심됩니다...');
      }
    } else
      print('File upload failed');
  }

  Future<void> _startListening() async {
    platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onCallEnded':
          print('[Main] >>>>>>>>>>>>>>>>>>>>>>>>> END <<<');
          if (_callStatus == 'Call Started') {
            print('[Main] >>>>>>>>>>>>> Upload <<<<<<<<<<<<');
            _uploadAudioFile();
          }
          setState(() {
            _callStatus = 'Call Ended';
          });
          break;
        case 'onCallStarted':
          print('[Main] >>> Start <<<<<<<<<<<<<<<<<<<<<<<');
          setState(() {
            _callStatus = 'Call Started';
          });
          break;
        default:
          throw MissingPluginException('notImplemented');
      }
    });

    try {
      await platform.invokeMethod('startListening');
    } on PlatformException catch (e) {
      print('Failed to start listening: ${e.message}');
    }
  }

  Widget pageView() {
    //Page이동 애니메이션
    return PageView.builder(
        itemCount: pageViewItem.length,
        scrollDirection: Axis.horizontal,
        controller: _controller,
        itemBuilder: (context, position) {
          return Transform(
            transform: Matrix4.identity()..rotateX(currentPageValue - position),
            child: pageViewItem[position],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    pageViewItem = [pageObject(1), pageObject(2), pageObject(3)];
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    final List<PlatformFile> _files = [];
    return GetMaterialApp(
      debugShowCheckedModeBanner: false, // 앱 상단에 "Debug" 라벨 숨기기

      home: Scaffold(
        extendBodyBehindAppBar: true, //영역을 확장하여 적용
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.black54, size: 25),
          title: const Text(
            "Voice Defender",
            style: TextStyle(
              fontSize: 32, // 글꼴 크기 조정
              fontWeight: FontWeight.bold, // 글꼴 두께 조정
              fontStyle: FontStyle.normal, // 글꼴 스타일 조정
              color: Colors.black, // 글꼴 색상 설정

              shadows: [
                Shadow(
                  blurRadius: 4.0,
                  color: Colors.grey,
                  offset: Offset(2.0, 2.0),
                ),
              ],
            ),
          ),

          toolbarHeight: 70,
          //   backgroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          // shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
          backgroundColor: Colors.transparent,
        ),
        drawer: Container(),
        body: Container(
          color: Colors.grey[200],
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: SizedBox(
                        height: height * 0.5,
                        width: width,
                        child: Stack(
                          children: [
                            Text('Call status: $_callStatus'),
                            pageView(),
                            Container(
                              alignment: Alignment(0, 0.75),

                              //dot indicator
                              child: SmoothPageIndicator(
                                controller: _controller,
                                count: 3,
                                effect: SwapEffect(),
                              ),
                              //next button
                            )
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: GestureDetector(
                        //전송 버튼

                        onTap: () async {
                          //전송시 동작
// 파일 선택 다이얼로그 열기
                          // _pickFile();

                          // FilePickerResult? result =
                          //     await FilePicker.platform.pickFiles(
                          //   type: FileType.custom,
                          //   allowedExtensions: ['m4a'], // 특정 확장자 필터링
                          //   withData: true,
                          //   // initialDirectory:
                          //   //     voiceRecorderDirPath, // 원하는 디렉토리 경로 설정
                          //   allowMultiple: false, // 다중 선택을 허용할 경우 true로 설정
                          // );

                          LoadingController.to.isLoading = true;
                          Future.delayed(Duration(seconds: 3), () {
                            LoadingController.to.isLoading = false;
                            Get.to(() => const ResultPage());
                          });
                        },

                        child: Container(
                          width: height * 0.2,
                          height: height * 0.2,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(70)),
                              border: Border.all(),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.pinkAccent, //그림자 색상
                                  offset: Offset(0, 3), //XY오프셋
                                  blurRadius: 10, //흐림 반경
                                  spreadRadius: 0, //그림자 확장
                                ),
                              ]),
                          child: Center(child: Text("전송버튼")),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const LoadingWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

Widget pageObject(int index) {
  Future<void> _getDummisData() async {
    Dio dio = Dio(
      // BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
      BaseOptions(baseUrl: 'http://222.105.252.28:8080'),
    );

    String url = '/api/ai/analysis-test';
    Response res = await dio.post(url);

    if (res.statusCode == 200) {
      print(res.data);

      if (res.data['isVoicePhishing'] == true) {
        FlutterLocalNotification.showNotification(
            '위험', '방금 통화는 보이스 피싱으로 의심됩니다...');
      }
    }
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 10, right: 10, top: 10),
    child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.withOpacity(0.7),
                  blurRadius: 5.0,
                  spreadRadius: 1.0,
                  offset: const Offset(0, 7)),
            ],
            borderRadius: BorderRadius.all(Radius.circular(50))),
        child: Container(
          // color: Colors.amberAccent,
          // alignment: Alignment.topLeft,
          child: (index == 1)
              ? Column(
                  // crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      ElevatedButton(
                        child: const Text("더미 데이터 요청"),
                        onPressed: _getDummisData,
                      ),
                      Text(
                        "애플리케이션 설명",
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Text(
                          "1. ",
                        ),
                      ),
                    ])
              : index == 2
                  ? Column(
                      // crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                            "애플리케이션 설명",
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(
                              "2. ",
                            ),
                          ),
                        ])
                  : index == 3
                      ? Column(
                          // crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                "애플리케이션 설명",
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Text(
                                  "3. ",
                                ),
                              ),
                            ])
                      : Text("NULL"),
        )),
  );
}
