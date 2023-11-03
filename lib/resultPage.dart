import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_defender/main.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      // extendBodyBehindAppBar: true,
      body: Container(
        color: Colors.grey[200],
        child: CustomScrollView(
          physics:
              BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              // title: IconButton(onPressed: () {}, icon: Icon(Icons.clear)),
              toolbarHeight: 80,
              title: Text("Voice Defender"),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white54,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        Get.back();
                      },
                    )),
              ),
              // foregroundColor: Colors.black,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              pinned: true,
              backgroundColor: Colors.blueAccent,
              // c: Colors.grey[200],
              expandedHeight: 300,
              flexibleSpace: FlexibleSpaceBar(
                  // collapseMode: CollapseMode.parallax,

                  // title: Text("인식결과"),
                  // titlePadding: EdgeInsets.only(bottom: 10),
                  // stretchModes: <StretchMode>[
                  //   StretchMode.zoomBackground,
                  //   StretchMode.blurBackground,
                  //   StretchMode.fadeTitle,
                  // ],
                  // centerTitle: true,
                  background: Container(
                decoration: const BoxDecoration(
                  // color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  // border: Border.all(),
                  color: Colors.pinkAccent,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("인식결과",
                          style: TextStyle(
                            fontSize: 32, // 글꼴 크기 조정
                            fontWeight: FontWeight.bold, // 글꼴 두께 조정
                            fontStyle: FontStyle.normal, // 글꼴 스타일 조정
                            color: Colors.black, // 글꼴 색상 설정
                          )),
                      Padding(
                        padding: const EdgeInsets.only(top: 30.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: width * 0.7,
                              height: height * 0.05,
                              decoration: const BoxDecoration(
                                  color: Colors.white60,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(30))),
                            ),
                            Column(
                              children: [
                                Text("위험",
                                    style: TextStyle(
                                      fontSize: 32, // 글꼴 크기 조정
                                      fontWeight: FontWeight.bold, // 글꼴 두께 조정
                                      fontStyle: FontStyle.normal, // 글꼴 스타일 조정
                                      color: Colors.black, // 글꼴 색상 설정
                                    )),
                                Text("89%",
                                    style: TextStyle(
                                      fontSize: 32, // 글꼴 크기 조정
                                      fontWeight: FontWeight.bold, // 글꼴 두께 조정
                                      fontStyle: FontStyle.normal, // 글꼴 스타일 조정
                                      color: Colors.black, // 글꼴 색상 설정
                                    )),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                // child: Column(children: [Text("안녕")]),
              )),

              bottom: PreferredSize(
                preferredSize: Size.fromHeight(30),
                child: Container(
                  color: Colors.white70,
                  width: double.maxFinite,
                  child: Row(
                    children: [
                      Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: Icon(Icons.home_outlined),
                                onPressed: () {
                                  Get.offAll(() => MyApp());
                                },
                              ),
                            ),
                          )),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Text(
                            "인식 결과",
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(""),
                      )
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(children: [
                    Container(
                      height: 700,
                      decoration: BoxDecoration(border: Border.all()),
                    ),
                    // StoreTitle(width, height, _storeValue),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
