import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:voice_defender/basicObject.dart';
import 'package:voice_defender/main.dart';
import 'package:lottie/lottie.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.response});
  final response;
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    List<String> reasons =
        List<String>.from(response?['phising_result']?['reasons'] ?? []);

    return Scaffold(
        // extendBodyBehindAppBar: true,
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
        body: SingleChildScrollView(
          physics:
              BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Container(
            decoration: const BoxDecoration(
              // color: Colors.black,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              // border: Border.all(),
              color: Colors.white60,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                // mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  resultPrint(response),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: TextObject("예방 Tip) 둘만 알고 있는 질문을 해보세요!",
                        fontsize: 15,
                        textColor: Colors.black87,
                        fw: FontWeight.w400),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30.0),
                    child: Center(
                      child: Container(
                        height: height * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(0.2), // 그림자 색상 및 불투명도 설정
                              blurRadius: 5, // 그림자의 흐림 정도 설정
                              offset: Offset(0, 2), // 그림자의 위치 설정
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 20.0),
                                  child: TextObject("딥보이스 위험도", fontsize: 20),
                                ),
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: width * 0.9,
                                            height: 13,
                                            decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                // border: Border.all(),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                          Container(
                                            width: width *
                                                0.9 *
                                                response['phising_result']
                                                        ['deep_voice_result']
                                                    ['confidence'],
                                            height: 13,
                                            decoration: BoxDecoration(
                                                color: Colors.red[600],
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextObject("0",
                                            fontsize: 15,
                                            textColor: Colors.grey[400]),
                                        TextObject("100",
                                            fontsize: 15,
                                            textColor: Colors.grey[400])
                                      ],
                                    )
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0),
                                  child: Divider(
                                      thickness: 1,
                                      height: 1,
                                      color: Colors.grey[300]),
                                ),
                                TextObject("보이스피싱 위험도", fontsize: 20),
                                Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: width * 0.9,
                                            height: 13,
                                            decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                // border: Border.all(),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                          Container(
                                            width: width *
                                                0.9 *
                                                response['phising_result']
                                                    ['confidence'],
                                            height: 13,
                                            decoration: BoxDecoration(
                                                color: Colors.red[600],
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextObject("0",
                                            fontsize: 15,
                                            textColor: Colors.grey[400]),
                                        TextObject("100",
                                            fontsize: 15,
                                            textColor: Colors.grey[400])
                                      ],
                                    )
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15.0),
                                  child: Divider(
                                      thickness: 1,
                                      height: 1,
                                      color: Colors.grey[300]),
                                ),
                              ]),
                        ),
                      ),
                    ),
                  ),
                  TextObject("의심되는 단어", fontsize: 20),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                        // height: 100,
                        // decoration: BoxDecoration(border: Border.all()),
                        child: Wrap(
                      children: reasons.map((reason) {
                        return Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Container(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextObject(reason,
                                  fontsize: 20, fw: FontWeight.w400),
                            ),
                            decoration: BoxDecoration(
                                color: Colors.white70,
                                border: Border.all(width: 3),
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        );
                      }).toList(),
                    )),
                  )
                ],
              ),
            ),
          ),
        ));
  }

  Widget resultPrint(response) {
    if (response['phising_result']['is_phising'] == false &&
        response['phising_result']['deep_voice_result']['is_deep_voice'] ==
            false) {
      return Row(children: [
        Lottie.asset('assets/lottie/safe.json', width: 50),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextObject("안전합니다", fontsize: 20, textColor: Colors.black87),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextObject("안심하고 통화하세요",
                  fontsize: 15, textColor: Colors.black87, fw: FontWeight.w500),
            ),
          ],
        )
      ]);
    } else if (response['phising_result']['is_phising'] == true &&
        response['phising_result']['deep_voice_result']['is_deep_voice'] ==
            false) {
      return Row(children: [
        Lottie.asset('assets/lottie/siren.json', width: 50),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextObject("보이스피싱 위험도가 높습니다.",
                fontsize: 20, textColor: Colors.red[700]),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextObject("보이스피싱에 주의하세요!!.",
                  fontsize: 15, textColor: Colors.black87, fw: FontWeight.w500),
            ),
          ],
        )
      ]);
    } else if (response['phising_result']['is_phising'] == false &&
        response['phising_result']['deep_voice_result']['is_deep_voice'] ==
            true) {
      return Row(children: [
        Lottie.asset('assets/lottie/siren.json', width: 50),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextObject("딥보이스 위험도가 높습니다.",
                fontsize: 20, textColor: Colors.red[700]),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextObject("딥보이스에 주의하세요!!.",
                  fontsize: 15, textColor: Colors.black87, fw: FontWeight.w500),
            ),
          ],
        )
      ]);
    } else if (response['phising_result']['is_phising'] == true &&
        response['phising_result']['deep_voice_result']['is_deep_voice'] ==
            true) {
      return Row(children: [
        Lottie.asset('assets/lottie/siren.json', width: 50),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextObject("위험도가 높게 나타났습니다.",
                fontsize: 20, textColor: Colors.red[700]),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextObject("보이스피싱과 딥보이스에 주의하세요!!.",
                  fontsize: 15, textColor: Colors.black87, fw: FontWeight.w500),
            ),
          ],
        )
      ]);
    }
    return SizedBox();
  }
}
