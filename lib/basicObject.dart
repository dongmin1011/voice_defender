import 'package:flutter/material.dart';

Widget TextObject(
  String msg, {
  Color textColor = Colors.black,
  double fontsize = 30,
  FontWeight fw = FontWeight.bold,
  bool center = true,
  bool showShadow = false, // 그림자 표시 여부를 추가합니다.
}) {
  final text = Text(
    msg,
    textAlign: center ? TextAlign.center : null,
    style: TextStyle(
      color: textColor,
      fontSize: fontsize,
      fontFamily: 'Jamsil',
      fontWeight: fw,
    ),
    // overflow: TextOverflow.ellipsis,
  );

  if (showShadow) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // 그림자 색상 및 불투명도 설정
            blurRadius: 5, // 그림자의 흐림 정도 설정
            offset: Offset(0, 2), // 그림자의 위치 설정
          ),
        ],
      ),
      child: text,
    );
  }

  return text;
}
