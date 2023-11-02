package com.example.voice_defender;

import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.voice_defender/call";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("startListening")) {
                        // 전화 상태 감지 시작
                        startListening(channel);
                        result.success(null);
                    }
                });
    }

    private void startListening(MethodChannel channel) {
        TelephonyManager telephonyManager = (TelephonyManager) getSystemService(TELEPHONY_SERVICE);
        MyPhoneStateListener phoneStateListener = new MyPhoneStateListener(channel);
        telephonyManager.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE);
    }

    static class MyPhoneStateListener extends PhoneStateListener {
        private final MethodChannel channel;

        public MyPhoneStateListener(MethodChannel channel) {
            this.channel = channel;
        }

        @Override
        public void onCallStateChanged(int state, String incomingNumber) {
            super.onCallStateChanged(state, incomingNumber);
            switch (state) {
                case TelephonyManager.CALL_STATE_IDLE:
                    // 전화 통화가 종료되었을 때 Flutter 앱에 이벤트 전달
                    channel.invokeMethod("onCallEnded", null);
                    break;
                case TelephonyManager.CALL_STATE_OFFHOOK:
                    // 전화 통화 중일 때 Flutter 앱에 이벤트 전달
                    channel.invokeMethod("onCallStarted", null);
                    break;

            }
        }
    }
}
