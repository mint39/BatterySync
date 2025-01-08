/// Flutter関係のインポート
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

/// Firebase関係のインポート
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// その他インポート
import 'dart:async';
import 'package:fl_chart/fl_chart.dart'; // バッテリー円グラフ用パッケージ
import 'package:device_info_plus/device_info_plus.dart'; // デバイス情報取得用パッケージ
import 'package:shared_preferences/shared_preferences.dart'; // ローカルデータ管理用
import 'package:google_generative_ai/google_generative_ai.dart'; // Gemini用
import 'settings.dart';
import 'login.dart';
import 'env/env.dart';

// メソッドチャンネル
const batteryChannel = MethodChannel('platform_method/battery');

// ローカルでバッテリーの状態を管理するプロバイダー
final batteryLevelProvider = StateProvider<int>((ref) => 0);

// Firestoreからバッテリーの状態をリアルタイムで取得するプロバイダー
final batteryStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('batteryStatus').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});

// ユーザーのデバイス情報を取得するプロバイダー
final userDevicesProvider = StreamProvider<List<DocumentSnapshot>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    return const Stream.empty(); // ユーザーがログインしていない場合は空のストリームを返す
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .collection('devices')
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

// isMountedProvider を追加
final isMountedProvider = StateProvider<bool>((ref) => true);

// デバイス情報のプロバイダー
final deviceInfoProvider = FutureProvider<List<String>>((ref) async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  late List<String> deviceInfoList;

  if (Platform.isAndroid) {
    AndroidDeviceInfo info = await deviceInfo.androidInfo;
    deviceInfoList = [info.brand, info.model, info.id];
  } else if (Platform.isIOS) {
    IosDeviceInfo info = await deviceInfo.iosInfo;
    deviceInfoList = [info.model, info.name, info.identifierForVendor.toString()];
  }

  return deviceInfoList;
});

// Gemini APIキー管理用
final generativeAiClientProvider = Provider<GenerativeModel>((ref) {
  return GenerativeModel(model: 'gemini-pro', apiKey: Env.Gemini);
});

// バッテリーログを取得するヘルパー関数
Future<List<Map<String, dynamic>>> getBatteryLogs() async {
  final prefs = await SharedPreferences.getInstance();
  final List<String> logs = prefs.getStringList('batteryLogs') ?? [];

  // ログをパースしてリストに変換
  return logs.map((log) {
    final parts = log.split(':');
    return {
      'timestamp': DateTime.parse(parts[0]),
      'batteryLevel': int.parse(parts[1]),
    };
  }).toList();
}

class ListPage extends ConsumerStatefulWidget {
  const ListPage({super.key});

  @override
  ListPageState createState() => ListPageState();
}

class ListPageState extends ConsumerState<ListPage> {
  @override
  void initState() {
    super.initState();

    // デバイス情報をロード
    ref.read(deviceInfoProvider);

    // バッテリーレベル変更のリスナーを登録
    batteryChannel.setMethodCallHandler((call) async {
      if (call.method == "batteryLevelChanged") {
        await getBatteryInfo();
        final level = call.arguments['level'];
      }
    });

    // 初回バッテリー情報取得
    getBatteryInfo().then((_) async {

      // 起動時にサインイン済みである場合、フラグを立てる
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          ref.read(isSigninProvider.notifier).state = true;
        } else {
          ref.read(isSigninProvider.notifier).state = false;
        }
      });

      int startLevel = 0;
      final res = await batteryChannel.invokeMethod('getBatteryInfo');
      startLevel = res["level"];
      saveBatteryInfo(startLevel); // 初回値をFirebaseに保存
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // バッテリー情報をFirestoreに保存
  Future<void> saveBatteryInfo(int batteryLevel) async {
    if (!mounted) return; // ウィジェットがマウントされていない場合、早期リターン

    // 非同期操作で context を使用する際に mounted をチェック
    if (!ref.read(isMountedProvider)) return;

    // ユーザーのサインインを確認
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return; // サインインしていない場合は終了する

    final userID = currentUser.uid; // ユーザー用のIDを取得する

    final deviceInfo = await ref.read(deviceInfoProvider.future);
    final deviceName = deviceInfo[1]; // デバイス名
    final deviceID = deviceInfo[2]; // デバイスID

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userID)
        .collection('devices')
        .doc(deviceID)
        .set({
      'deviceID': deviceID,
      'deviceName': deviceName,
      'batteryLevel': batteryLevel,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ローカルにログを保存
    await saveBatteryLogLocally(batteryLevel);
  }

  Future<void> saveBatteryLogLocally(int batteryLevel) async {
    final prefs = await SharedPreferences.getInstance();

    // ローカル履歴を取得
    final List<String> logs = prefs.getStringList('batteryLogs') ?? [];

    // 現在時刻とバッテリー残量を追加
    final timestamp = DateTime.now().toIso8601String();
    logs.add('$timestamp:$batteryLevel');

    // 履歴を保存
    const maxLogs = 200;
    if (logs.length > maxLogs) {
      logs.removeRange(0, logs.length - maxLogs);
    }

    await prefs.setStringList('batteryLogs', logs);
  }

  // バッテリー情報を取得
  Future<void> getBatteryInfo() async {
    if (!mounted) return; // ウィジェットがマウントされていない場合、早期リターン

    int batteryLevel = 0;
    try {
      final res = await batteryChannel.invokeMethod('getBatteryInfo');
      batteryLevel = res["level"];
    } on PlatformException {
      batteryLevel = -1;
    }

    if (mounted) { // mounted をチェックしてウィジェットがアクティブか確認
      // ローカル状態の更新
      ref
          .read(batteryLevelProvider.notifier)
          .state = batteryLevel;
    }

    // ユーザーのサインインを確認
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return; // サインインしていない場合は終了する

    // Firestoreに保存
    await saveBatteryInfo(batteryLevel);
  }

  // バッテリー残量予測
  final batteryPredictionProvider = FutureProvider<String>((ref) async {
    final generativeAiClient = ref.read(generativeAiClientProvider);

    // Fetch battery logs
    final logs = await getBatteryLogs();

    // Format logs as a prompt
    final formattedLogs = logs.map((log) {
      final timestamp = log['timestamp'] as String;
      final batteryLevel = log['batteryLevel'] as int;
      return '$timestamp: $batteryLevel%';
    }).join('\n');

    final prompt = [Content.text('''
      以下はデバイスの過去のバッテリー残量推移データです:
      $formattedLogs
  
      このデータに基づき、次の24時間のバッテリー残量推移を予測してください。
      出力には、次の24時間の1時間毎の時刻と予想バッテリー残量を出力してください。
    '''
    )];

    try {
      // Convert the string prompt to Iterable<Content>
      final response = await generativeAiClient.generateContent(prompt);

      // Access the generated text
      final generatedText = response.text ?? '予測結果を取得できませんでした';

      return generatedText;
    } catch (e) {
      return '予測に失敗しました: $e';
    }
  });

  @override
  Widget build(BuildContext context) {
    final batteryLevel = ref.watch(batteryLevelProvider);
    final deviceInfoAsync = ref.watch(deviceInfoProvider);
    final userDevicesAsync = ref.watch(userDevicesProvider);
    final batteryPrediction = ref.watch(batteryPredictionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          'BatterySync',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) {
                  return const SettingsPage();
                }),
              );
            },
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).iconTheme.color,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.black,
        backgroundColor: Colors.teal,
        onRefresh: () async {
          getBatteryInfo();
        },
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              deviceInfoAsync.when(
                data: (deviceInfo) {
                  final deviceName = deviceInfo[1];
                  return Card(
                    margin: const EdgeInsets.all(15),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 132,
                            height: 150,
                            child: pieChart(batteryLevel.toDouble(), 32), // 円グラ2
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  deviceName,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.titleLarge?.color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '$batteryLevel%',
                                  style: TextStyle(
                                    color: color(batteryLevel),
                                    fontSize: 50,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => const Text("Error loading device info"),
              ),

              // 他のデバイスのリストをカード型で表示
              userDevicesAsync.when(
                data: (devices) {
                  final currentDeviceId = deviceInfoAsync.value?[2] ?? "";
                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: devices.length,
                    padding: const EdgeInsets.all(15),
                    itemBuilder: (context, index) {
                      final device = devices[index].data() as Map<String, dynamic>;
                      final deviceId = device['deviceID'] as String;
                      if (deviceId == currentDeviceId) {
                        return const SizedBox.shrink();
                      }
                      final deviceName = device['deviceName'] as String;
                      final batteryLevel = device['batteryLevel'] as int;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: pieChart(batteryLevel.toDouble(), 25), // 円グラフ
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      deviceName,
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.titleLarge?.color,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '$batteryLevel%',
                                      style: TextStyle(
                                        color: color(batteryLevel),
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => Text('Error: $error'),
              ),

              // バッテリー予測結果を表示
              batteryPrediction.when(
                data: (prediction) {
                  // 未ログインの場合は予測をスキップ
                  if (FirebaseAuth.instance.currentUser == null) {
                    return const SizedBox.shrink(); // 空のウィジェットを返す
                  }

                  return Padding(
                    padding: const EdgeInsets.all(15),
                    child: Card(
                      margin: const EdgeInsets.only(top: 20),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'バッテリー予測結果:',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.titleLarge?.color,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              prediction,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.titleLarge?.color,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const Center(child: Text("予測に失敗しました")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color color(int level) {
    if (level > 19) {
      return Colors.green.shade300;
    } else if (19 > level && level > 10) {
      return Colors.amber.shade300;
    } else {
      return Colors.red.shade300;
    }
  }

  PieChart pieChart(double level, double radius) => PieChart(
    PieChartData(
      startDegreeOffset: 270,
      sectionsSpace: 0,
      centerSpaceRadius: radius % 40,
      sections: [
        PieChartSectionData(
            color: Colors.white,
            value: 100 - level,
            title: '',
            radius: radius),
        PieChartSectionData(
            color: color(level.toInt()),
            value: level,
            title: '',
            radius: radius),
      ],
    ),
  );
}
