import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:voice_defender/resultPage.dart';

import 'loadingWidget.dart';

void main() {
  runApp(const MyApp());
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

  @override
  void initState() {
    //page컨트롤러 초기화
    super.initState();
    // _currentIndex = 0;
    _controller = PageController(initialPage: -1, viewportFraction: 0.8);
    _controller.addListener(() {
      setState(() {
        currentPageValue = _controller.page;
      });
    });
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
                          // Directory rootDir =
                          //     await getApplicationDocumentsDirectory();
                          // String voiceRecorderDirPath =
                          //     '${rootDir.path}/Voice Recorder';
                          // print(voiceRecorderDirPath);
                          // FilePickerResult? result =
                          //     await FilePicker.platform.pickFiles(
                          //   type: FileType.custom,
                          //   allowedExtensions: ['m4a'], // 특정 확장자 필터링
                          //   withData: true,
                          //   initialDirectory:
                          //       voiceRecorderDirPath, // 원하는 디렉토리 경로 설정
                          //   allowMultiple: false, // 다중 선택을 허용할 경우 true로 설정
                          // );
                          // if (result != null) {
                          //   PlatformFile file = result.files.first;

                          //   // 선택한 파일을 사용하여 작업 수행
                          //   print('선택한 파일 경로: ${file.path}');
                          // } else {
                          //   // 사용자가 파일 선택을 취소한 경우
                          //   print('파일 선택 취소');
                          // }

                          FilePickerResult? result =
                              await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['m4a'], // 특정 확장자 필터링
                            withData: true,
                            // initialDirectory:
                            //     voiceRecorderDirPath, // 원하는 디렉토리 경로 설정
                            allowMultiple: false, // 다중 선택을 허용할 경우 true로 설정
                          );
                          // PlatformFile? uploadedFiles =
                          //     (await FilePicker.platform.pickFiles(
                          //   allowedExtensions: ['m4a'],
                          //   allowMultiple: false,
                          // ));
                          //         ?.files;
                          // setState(() {
                          //   for (PlatformFile file in uploadedFiles!) {
                          //     _files.add(file);
                          //   }
                          // });

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
