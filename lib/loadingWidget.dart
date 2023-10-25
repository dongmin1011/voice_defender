import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(
      //isLoading(obs)가 변경되면 다시 그림.
      () => Offstage(
        offstage: !LoadingController.to.isLoading, // isLoading이 false면 감춰~
        child: Stack(children: const <Widget>[
          //다시 stack
          Opacity(
            //뿌옇게~
            opacity: 0.2,
            child:
                ModalBarrier(dismissible: false, color: Colors.black), //클릭 못하게~
          ),
          Center(
            child: SpinKitWaveSpinner(
              size: 100,
              color: Colors.lightBlueAccent,
              trackColor: Colors.lightGreenAccent,
              waveColor: Colors.greenAccent,
            ),
          ),
        ]),
      ),
    );
  }
}

class LoadingController extends GetxController {
  static LoadingController get to => Get.put(LoadingController());

  final _isLoading = false.obs;

  bool get isLoading => _isLoading.value;
  set isLoading(bool value) => _isLoading.value = value;
  void setIsLoading(bool value) => _isLoading.value = value;
}
