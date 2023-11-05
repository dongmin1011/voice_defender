import 'dart:convert';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
import 'package:voice_defender/sql/file.dart';
import 'package:voice_defender/sql/fileDB.dart';
import 'loadingWidget.dart';
import 'notification.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool autoSendSwitchValue = prefs.getBool('autoSendSwitchValue') ?? true;
  bool notificationSwitchValue =
      prefs.getBool('notificationSwitchValue') ?? true;

  await prefs.setBool('autoSendSwitchValue', autoSendSwitchValue);
  await prefs.setBool('notificationSwitchValue', notificationSwitchValue);

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
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: '후아유 실행중',
      initialNotificationContent: '안심하고 통화하세요!',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
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

class MyHomePageController extends GetxController {}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late List pageViewItem;
  late PageController _controller;
  late bool autoSendSwitchValue;
  late bool notificationSwitchValue;
  static dynamic currentPageValue = 0.0;

  static const platform = MethodChannel('com.example.voice_defender/call');
  String _callStatus = 'Unknown';

  // bool autoSendSwitchValue = true;
  // bool notificationSwitchValue = true;

  final database = FileDB();
  final MyHomePageController _myController = Get.put(MyHomePageController());

  @override
  void initState() {
    //page컨트롤러 초기화
    super.initState();
    database.initDB();

    _loadSwitchValues();
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

  void _loadSwitchValues() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      autoSendSwitchValue = prefs.getBool('autoSendSwitchValue') ?? true;
      notificationSwitchValue =
          prefs.getBool('notificationSwitchValue') ?? true;
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
      // BaseOptions(baseUrl: dotenv.env['BASE_URL'] ?? 'http://localhost:8080'),
      BaseOptions(baseUrl: 'http://222.105.252.28:8080'),
    );

    String url = '/api/ai/analysis';
    String filename = latestFilePath.split('/').last;

    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        latestFilePath,
        filename: filename,
      ),
    });

    Response res = await dio.post(url, data: formData);

    if (res.statusCode == 200) {
      print('[Main] data >> ${res.data}');

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      bool notificationSwitchValue =
          prefs.getBool('notificationSwitchValue') ?? true;

      if (res.data['phising_result']['is_phising']) {
        print('[Main] 보이스피싱 의심');
        FlutterLocalNotification.showNotification(
            '보이스피싱', '방금 통화는 보이스 피싱으로 의심됩니다.');
      } else if (res.data['phising_result']['deep_voice_result']
          ['is_deep_voice']) {
        print('[Main] 딥보이스 탐지');
        FlutterLocalNotification.showNotification(
            '딥보이스', '방금 통화는 딥보이스가 탐지되었습니다.');
      } else {
        print('[Main] 정상통화');
        if (!notificationSwitchValue) {
          FlutterLocalNotification.showNotification(
              '후아유', '안심하세요. 아무것도 탐지되지 않았습니다.');
        }
      }
    }
  }

  Future<void> _startListening() async {
    platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onCallEnded':
          print('[Main] >>>>>>>>>>>>>>>>>>>>>>>>> END <<<');
          if (_callStatus == 'Call Started') {
            print('[Main] >>>>>>>>>>>>> Upload <<<<<<<<<<<<');

            final SharedPreferences prefs =
                await SharedPreferences.getInstance();

            bool autoSendSwitchValue =
                prefs.getBool('autoSendSwitchValue') ?? true;
            if (autoSendSwitchValue) {
              _uploadAudioFile();
            }
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
  String file_name = "파일이 존재하지 않습니다";

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
      print(path?.split('/'));
      List<String>? parts = path?.split('/');

      if (parts != null && parts.isNotEmpty) {
        file_name = parts.last; // 리스트의 마지막 요소 가져오기
      }
      setState(() {
        _filePath = path;
      });
      // _uploadFile(path!); // 파일을 선택한 후 바로 업로드
    } else {
      // 사용자가 파일 선택을 취소한 경우
      print('No file selected');
    }
  }

  Future<void> _uploadFile(String filePath) async {
    File file = File(filePath);
    LoadingController.to.isLoading = true;
    // String uploadUrl = 'http://222.105.252.28:8080/api/ai/analysis-test';
    String uploadUrl = 'http://222.105.252.28:8080/api/ai/analysis';
    Dio dio = Dio();

    // String ext = file.uri.pathSegments.last.split('.').last;
    // String filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    // print(ext);
    // print(filename);

    String filename = file.uri.pathSegments.last.split('/').last;

    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        // filename: filename
        filename: filename + ".m4a",
      ),
    });

    Response response = await dio.post(uploadUrl, data: formData);
    // var response = await dio.post(uploadUrl);

    if (response.statusCode == 200) {
      print('File upload successful');
      LoadingController.to.isLoading = false;

      print(response);
      // print(response.runtimeType);

      final file = File_table(
          filename: response.data['filename'],
          created_at: response.data['created_at'],
          is_phising: response.data['phising_result']['is_phising'],
          confidence: response.data['phising_result']['confidence'],
          reasons: jsonEncode(response.data['phising_result']['reasons']),
          Text: response.data['phising_result']['text'],
          is_deep_voice: response.data['phising_result']['deep_voice_result']
              ['is_deep_voice'],
          deep_voice_confidence: response.data['phising_result']
              ['deep_voice_result']['confidence']);
      database.insert(file);
      Get.to(() => ResultPage(
            response: response.data,
          ));
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

      home: GetBuilder<MyHomePageController>(
        builder: (controller) => Stack(
          children: [
            Scaffold(
                // extendBodyBehindAppBar: true, //영역을 확장하여 적용
                // backgroundColor: Colors.grey[200],
                appBar: AppBar(
                  iconTheme:
                      const IconThemeData(color: Colors.black54, size: 25),

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
                    color: Colors.blue.shade400,
                    animationDuration: const Duration(milliseconds: 300),
                    animationCurve: Curves.decelerate,
                    onTap: (value) {
                      setState(() {
                        index = value;
                      });
                    },
                    items: [
                      Icon(
                        Icons.home,
                        color: Colors.white,
                      ),
                      Icon(Icons.add, color: Colors.white),
                      Icon(Icons.settings, color: Colors.white)
                    ]),
                // drawer: Container(),
                body: Container(
                    // color: Colors.grey[200],
                    child: index == 0
                        ? MainPage(width, height, controller)
                        : index == 1
                            ? UploadPage(width, height)
                            : Container(
                                child: Column(
                                  // mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 20.0, bottom: 20),
                                      child: TextObject("환경 설정", center: false),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 20.0, bottom: 10),
                                      child: TextObject("전송 기능", fontsize: 20),
                                    ),
                                    Center(
                                      child: Column(children: [
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            width: width * 0.9,
                                            decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  TextObject("통화 종료 후 자동 분석",
                                                      fontsize: 20,
                                                      fw: FontWeight.w400),
                                                  CupertinoSwitch(
                                                    value: autoSendSwitchValue,
                                                    activeColor: CupertinoColors
                                                        .activeGreen,
                                                    onChanged:
                                                        (bool? value) async {
                                                      final SharedPreferences
                                                          prefs =
                                                          await SharedPreferences
                                                              .getInstance();
                                                      setState(() {
                                                        autoSendSwitchValue =
                                                            value ?? false;
                                                      });
                                                      await prefs.setBool(
                                                          'autoSendSwitchValue',
                                                          autoSendSwitchValue);
                                                    },
                                                  )
                                                  // CupertinoSwitch(
                                                  //     value: autoSendSwitchValue,
                                                  //     activeColor: CupertinoColors
                                                  //         .activeGreen,
                                                  //     onChanged: (bool? Value) {
                                                  //       setState(() {
                                                  //         autoSendSwitchValue =
                                                  //             Value ?? false;
                                                  //       });
                                                  //     })
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Container(
                                            width: width * 0.9,
                                            decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  TextObject("보이스피싱 의심될 때만 알림",
                                                      fontsize: 20,
                                                      fw: FontWeight.w400),
                                                  CupertinoSwitch(
                                                      value:
                                                          notificationSwitchValue,
                                                      activeColor:
                                                          CupertinoColors
                                                              .activeGreen,
                                                      onChanged:
                                                          (bool? Value) async {
                                                        final SharedPreferences
                                                            prefs =
                                                            await SharedPreferences
                                                                .getInstance();
                                                        setState(() {
                                                          notificationSwitchValue =
                                                              Value ?? false;
                                                        });
                                                        await prefs.setBool(
                                                            'notificationSwitchValue',
                                                            notificationSwitchValue);
                                                      })
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 20, horizontal: 20),
                                          child: Divider(
                                            thickness: 2,
                                            height: 2,
                                          ),
                                        ),
                                      ]),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 20.0, bottom: 10),
                                      child:
                                          TextObject("개인정보 처리방침", fontsize: 20),
                                    ),
                                    Center(
                                      child: Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              width: width * 0.9,
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 15),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    TextObject("개인정보 처리방침",
                                                        fontsize: 20,
                                                        fw: FontWeight.w400),
                                                    Row(
                                                      children: [
                                                        TextObject("상세보기",
                                                            fontsize: 15,
                                                            fw: FontWeight
                                                                .w200),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          color:
                                                              Colors.grey[400],
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              width: width * 0.9,
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 15),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    TextObject("정책",
                                                        fontsize: 20,
                                                        fw: FontWeight.w400),
                                                    Row(
                                                      children: [
                                                        TextObject("상세보기",
                                                            fontsize: 15,
                                                            fw: FontWeight
                                                                .w200),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          color:
                                                              Colors.grey[400],
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Container(
                                              width: width * 0.9,
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8.0,
                                                        vertical: 15),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    TextObject("이용약관",
                                                        fontsize: 20,
                                                        fw: FontWeight.w400),
                                                    Row(
                                                      children: [
                                                        TextObject("상세보기",
                                                            fontsize: 15,
                                                            fw: FontWeight
                                                                .w200),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_ios_rounded,
                                                          color:
                                                              Colors.grey[400],
                                                        )
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))),
            LoadingWidget(),
          ],
        ),
      ),
    );
  }

  Container UploadPage(double width, double height) {
    return Container(
        child: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextObject("음성 파일 업로드", center: false),
                ),
                TextObject("검사를 원하는 음성파일을 업로드 해주세요",
                    center: false, fontsize: 15, fw: FontWeight.w400)
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
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2), // 그림자 색상 및 불투명도 설정
                      blurRadius: 5, // 그림자의 흐림 정도 설정
                      offset: Offset(0, 2), // 그림자의 위치 설정
                    ),
                  ]),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Row 내부의 위젯을 수평 가운데 정렬

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
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                            child: Container(
                              width: width * 0.4,
                              height: height * 0.15,
                              decoration: BoxDecoration(
                                color: Colors.white70,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
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
                          padding: const EdgeInsets.all(8.0),
                          child: TextObject(file_name,
                              fontsize: 15, fw: FontWeight.w400),
                        )
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Row 내부의 위젯을 수평 가운데 정렬

                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
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
                                        BorderRadius.all(Radius.circular(10))),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Image.asset(
                                      'assets/data/folder.png',
                                      width: 30,
                                    ),
                                    TextObject("업로드하기", fontsize: 15),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
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
                                        BorderRadius.all(Radius.circular(10))),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Image.asset(
                                      'assets/data/find.png',
                                      width: 30,
                                    ),
                                    TextObject("분석하기", fontsize: 15),
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
        ]));
  }

  // final items = List<String>.generate(30, (i) => "Item ${i + 1}");
  Future<void> _onDismissed(int index, int id) async {
    await database.delete(id);
    // final item = items[index];
    // setState(() => items.removeAt(index));
  }

  Column MainPage(double width, double height, controller) {
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
                  child: FutureBuilder(
                    future: database.selectAll(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return TextObject("최근 분석 결과가 없습니다.",
                            fontsize: 20, fw: FontWeight.w400);
                      }
                      final items = snapshot.data!;
                      return SlidableAutoCloseBehavior(
                        closeWhenOpened: true,
                        child: ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              item['is_phising'] = (item['is_phising'] != 0);
                              item['is_deep_voice'] =
                                  (item['is_deep_voice'] != 0);
                              // print();
                              // item['reasons'].add("은행");
                              // item['reasons'].add("돈");
                              print(item);

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7.0),
                                child: Slidable(
                                  key: Key(item['id'].toString()),
                                  endActionPane: ActionPane(
                                    motion: const StretchMotion(),
                                    dismissible: DismissiblePane(
                                      onDismissed: () {
                                        _onDismissed(index, item['id']);
                                        controller.update();

                                        // index -= 1;
                                      },
                                    ),
                                    children: [
                                      SlidableAction(
                                          backgroundColor: Colors.red,
                                          icon: Icons.delete,
                                          label: 'delete',
                                          onPressed: (context) {
                                            _onDismissed(index, item['id']);
                                            controller.update();
                                          })
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      // final reasonsJson = item['reasons'];
                                      // print(reasonsJson.runtimeType);

                                      final Map<String, dynamic> phisingResult =
                                          {
                                        "id": item["id"],
                                        'filename': item["filename"],
                                        'created_at': item["created_at"],
                                        "phising_result": {
                                          "is_phising": item["is_phising"],
                                          "confidence": item["confidence"],
                                          "reasons": item[
                                              'reasons'], // "reasons" 리스트 추가
                                          "text": item['text'],
                                          "deep_voice_result": {
                                            "is_deep_voice":
                                                item["is_deep_voice"],
                                            "confidence":
                                                item["deep_voice_confidence"],
                                          }
                                        }
                                      };
                                      print(phisingResult);
                                      print(phisingResult['phising_result']
                                                  ['deep_voice_result']
                                              ['confidence']
                                          .runtimeType);
                                      Get.to(() =>
                                          ResultPage(response: phisingResult));
                                    },
                                    child: Container(
                                        // width: width * 0.7,
                                        padding: EdgeInsets.all(10),
                                        height: 90,
                                        decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(30)),
                                        child: Row(
                                          children: [
                                            resultImage(item["is_phising"],
                                                item["is_deep_voice"]),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: SizedBox(
                                                width: width * 0.65,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        SizedBox(
                                                          width: width * 0.4,
                                                          child: TextObject(
                                                              item['filename'],
                                                              fontsize: 20,
                                                              overflow: true,
                                                              maxLine: 1),
                                                        ),
                                                        TextObject(
                                                            item['created_at']
                                                                    .substring(
                                                                        2, 4) +
                                                                '/' +
                                                                item['created_at']
                                                                    .substring(
                                                                        4, 6) +
                                                                ' ' +
                                                                item['created_at']
                                                                    .substring(
                                                                        6, 8) +
                                                                ":" +
                                                                item['created_at']
                                                                    .substring(
                                                                        8, 10),
                                                            fontsize: 10,
                                                            textColor:
                                                                Colors.black54),
                                                      ],
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8.0),
                                                      child: TextObject(
                                                          item['text'],
                                                          fontsize: 15,
                                                          fw: FontWeight.w300,
                                                          overflow: true,
                                                          maxLine: 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )),
                                  ),
                                ),
                              );
                            }),
                      );
                    },
                  )))
        ]);
  }

  Image resultImage(bool phising, bool deepVoice) {
    if (phising == false && deepVoice == false) {
      return Image.asset(
        'assets/data/shield.png',
        width: 50,
      );
    } else if ((phising == true && deepVoice == false) ||
        (phising == false && deepVoice == true)) {
      return Image.asset(
        'assets/data/caution.png',
        width: 50,
      );
    }
    return Image.asset(
      'assets/data/emergency.png',
      width: 50,
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

      if (res.data['is_phising'] == true) {
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
