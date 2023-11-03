import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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
import 'package:voice_defender/basicObject.dart';
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

  String? _filePath;
  List<String> _files = [];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,

      // allowedExtensions: ['m4a'], // 특정 확장자 필터링
      // withData: true,
      // initialDirectory: "/storage/emulated/0/Voice Recorder/", // 원하는 디렉토리 경로 설정
      // allowMultiple: false, // 다중 선택을 허용할 경우 true로 설정
    );
    if (result != null) {
      String? path = result.files.single.path;

      setState(() {
        _filePath = path;
      });
      _uploadFile(path!); // 파일을 선택한 후 바로 업로드
    } else {
      // 사용자가 파일 선택을 취소한 경우
      print('No file selected');
    }
  }

  Future<void> _uploadFile(String filePath) async {
    File file = File(filePath);

    String uploadUrl = 'http://222.105.252.28:8080/api/ai/uploadfile';

    Dio dio = Dio();

    String ext = file.uri.pathSegments.last.split('.').last;
    String filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';

    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: filename,
      ),
    });

    Response response = await dio.post(uploadUrl, data: formData);

    if (response.statusCode == 200) {
      print('File upload successful');
      // LoadingController.to.isLoading = false;
      // Get.to(() => const ResultPage());
    } else {
      print('File upload failed');
    }
  }

  Future<void> _getRequest() async {
    String url = 'http://222.105.252.28:8080/api/ai';

    Dio dio = Dio();

    try {
      Response response = await dio.get(url);
      print('Response data: ${response.data}');
    } catch (e) {
      print('Request failed with error: $e');
    }
  }

  Future<void> _listFiles() async {
    Directory dir = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = dir.listSync();
    List<String> filePaths = fileList.map((file) => file.path).toList();
    setState(() {
      _files = filePaths;
    });
  }

  int index = 0;
  @override
  Widget build(BuildContext context) {
    pageViewItem = [pageObject(1), pageObject(2), pageObject(3)];
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    final List<PlatformFile> _files = [];
    return GetMaterialApp(
      debugShowCheckedModeBanner: false, // 앱 상단에 "Debug" 라벨 숨기기

      home: Scaffold(
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
              onTap: (value) {
                setState(() {
                  index = value;
                });
              },
              items: [Icon(Icons.home), Icon(Icons.add), Icon(Icons.settings)]),
          // drawer: Container(),
          body: Container(
              // color: Colors.grey[200],
              child: index == 0
                  ? MainPage(width: width, height: height)
                  : index == 1
                      ? Container(
                          child: Column(
                              // mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: TextObject("음성 파일 업로드",
                                          center: false),
                                    ),
                                    TextObject("검사를 원하는 음성파일을 업로드 해주세요",
                                        center: false,
                                        fontsize: 15,
                                        fw: FontWeight.w400)
                                  ],
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: width * 0.8,
                                  height: height * 0.5,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      // border: Border.all(),
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(
                                              0.2), // 그림자 색상 및 불투명도 설정
                                          blurRadius: 5, // 그림자의 흐림 정도 설정
                                          offset: Offset(0, 2), // 그림자의 위치 설정
                                        ),
                                      ]),
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .center, // Row 내부의 위젯을 수평 가운데 정렬

                                          children: [
                                            TextObject("파일 업로드", fontsize: 25),
                                            Icon(
                                              Icons.mic,
                                              size: 50,
                                            )
                                          ],
                                        ),
                                        Stack(
                                          alignment: Alignment.bottomCenter,
                                          children: [
                                            Container(
                                              width: width * 0.6,
                                              height: height * 0.25,
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Center(
                                                child: Container(
                                                  width: width * 0.4,
                                                  height: height * 0.15,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white70,
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            20.0),
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        _pickFile();
                                                      },
                                                      child: Image.asset(
                                                        'assets/data/voice.png',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: TextObject("file_name",
                                                  fontsize: 15,
                                                  fw: FontWeight.w400),
                                            )
                                          ],
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 15.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment
                                                .center, // Row 내부의 위젯을 수평 가운데 정렬

                                            children: [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    _pickFile();
                                                  },
                                                  child: Container(
                                                    width: width * 0.3,
                                                    height: height * 0.08,
                                                    decoration: BoxDecoration(
                                                        color: Colors.blue[100],
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    10))),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceAround,
                                                      children: [
                                                        Image.asset(
                                                          'assets/data/folder.png',
                                                          width: 30,
                                                        ),
                                                        TextObject("업로드하기",
                                                            fontsize: 15),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    if (_filePath == null) {
                                                      _pickFile();
                                                    } else {
                                                      _uploadFile(_filePath!);
                                                    }
                                                  },
                                                  child: Container(
                                                    width: width * 0.3,
                                                    height: height * 0.08,
                                                    decoration: BoxDecoration(
                                                        color: Colors.blue[100],
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    10))),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceAround,
                                                      children: [
                                                        Image.asset(
                                                          'assets/data/find.png',
                                                          width: 30,
                                                        ),
                                                        TextObject("분석하기",
                                                            fontsize: 15),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      ]),
                                ),
                              )
                            ]))
                      : Container(
                          child: Column(
                              // mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 30),
                                child: TextObject("설정", center: false),
                              ),
                            ])))),
    );
  }
}

class MainPage extends StatelessWidget {
  const MainPage({
    super.key,
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      // mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 20.0, bottom: 30),
          child: TextObject("최근 분석 결과", center: false),
        ),

        Center(
          child: Container(
            width: width * 0.9,
            height: height * 0.5,
            // decoration: BoxDecoration(border: Border.all()),
            child: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Container(
                      // width: width * 0.7,
                      height: height * 0.1,
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      child: index % 2 == 0
                          ? Row(
                              children: [
                                Image.asset(
                                  'assets/data/emergency.png',
                                  width: 50,
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextObject("존내 위험", fontsize: 25),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: TextObject("존내 위험",
                                          fontsize: 20, fw: FontWeight.w300),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Image.asset('assets/data/shield.png',
                                    width: 50),
                                TextObject("존내 안전", fontsize: 20),
                              ],
                            ),
                    ),
                  );
                }),
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.all(30.0),
        //   child: Center(
        //     child: GestureDetector(
        //       onTap: () {
        //         Get.to(() => UploadPage());
        //       },
        //       child: Container(
        //         width: height * 0.1,
        //         height: height * 0.1,
        //         decoration: BoxDecoration(
        //           color: Colors.blueAccent.shade200,
        //           borderRadius:
        //               const BorderRadius.all(Radius.circular(70)),
        //           // border: Border.all(),
        //           // boxShadow: const [
        //           //   BoxShadow(
        //           //     color: Colors.pinkAccent, //그림자 색상
        //           //     offset: Offset(0, 3), //XY오프셋
        //           //     blurRadius: 10, //흐림 반경
        //           //     spreadRadius: 0, //그림자 확장
        //           //   ),
        //           // ]
        //         ),
        //         child: Center(
        //             child: Icon(
        //           Icons.add,
        //           size: 50,
        //           color: Colors.white60,
        //         )),
        //       ),
        //     ),
        //   ),
        // ),

        // Padding(
        //   padding: const EdgeInsets.only(top: 50.0),
        //   child: SizedBox(
        //     height: height * 0.5,
        //     width: width,
        //     child: Stack(
        //       children: [
        //         pageView(),
        //         Container(
        //           alignment: Alignment(0, 0.75),

        //           //dot indicator
        //           child: SmoothPageIndicator(
        //             controller: _controller,
        //             count: 3,
        //             effect: SwapEffect(),
        //           ),
        //           //next button
        //         )
        //       ],
        //     ),
        //   ),
        // ),
        // Padding(
        //   padding: const EdgeInsets.only(top: 40.0),
        //   child: GestureDetector(
        //전송 버튼

//                         onTap: () async {
//                           //전송시 동작
// // 파일 선택 다이얼로그 열기
//                           _pickFile();

//                           LoadingController.to.isLoading = true;
//                           Future.delayed(Duration(seconds: 5), () {
//                             LoadingController.to.isLoading = false;
//                             Get.to(() => const ResultPage());
//                           });
//                         },

        // child: Container(
        //   width: height * 0.2,
        //   height: height * 0.2,
        //   decoration: BoxDecoration(
        //       color: Colors.white,
        //       borderRadius:
        //           const BorderRadius.all(Radius.circular(70)),
        //       border: Border.all(),
        //       boxShadow: const [
        //         BoxShadow(
        //           color: Colors.pinkAccent, //그림자 색상
        //           offset: Offset(0, 3), //XY오프셋
        //           blurRadius: 10, //흐림 반경
        //           spreadRadius: 0, //그림자 확장
        //         ),
        //       ]),
        //   child: Center(child: Text("전송버튼")),
        // ),
        // ),
        // )
      ],
    );
  }
}

Widget pageObject(int index) {
  Future<void> _getDummisData() async {
    Dio dio = Dio(
      BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
      // BaseOptions(baseUrl: 'http://222.105.252.28:8080'),
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
