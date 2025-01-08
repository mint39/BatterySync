package jp.co.epsilonlabs.batterysync;

// MethodChannelのため
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;

// バッテリー取得のため
import android.content.Context;
import android.os.BatteryManager;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.content.BroadcastReceiver;

// 追加のプラグイン
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private MethodChannel channel;
    private BroadcastReceiver batteryReceiver;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), "platform_method/battery");

        channel.setMethodCallHandler((methodCall, result) -> {
            if (methodCall.method.equals("getBatteryInfo")) {
                // バッテリー残量を即時取得して返す
                int level = getBatteryLevel();
                Map<String, Object> res = new HashMap<>();
                res.put("device", "Android");
                res.put("level", level);
                result.success(res);
            } else {
                result.notImplemented();
            }
        });

        // BroadcastReceiverを登録してバッテリー残量変化を検知
        batteryReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                int level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                if (level != -1) {
                    // バッテリーレベルが変化した場合のみFlutterに通知
                    Map<String, Object> args = new HashMap<>();
                    args.put("level", level);
                    channel.invokeMethod("batteryLevelChanged", args);
                }
            }
        };

        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        registerReceiver(batteryReceiver, filter);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        // BroadcastReceiverの登録を解除
        unregisterReceiver(batteryReceiver);
    }

    private int getBatteryLevel() {
        BatteryManager manager = (BatteryManager) getSystemService(Context.BATTERY_SERVICE);
        return manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
    }
}
