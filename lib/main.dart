/// Flutter関係のインポート
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase関係のインポート
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// その他インポート
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart'; // ローカルへのデータ保存用パッケージ
import 'package:device_info_plus/device_info_plus.dart'; // デバイス情報取得用パッケージ

import 'device_list.dart';
import 'introduction.dart';

// SharedPreferencesの初期化と取得状態
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs;
});

// 初回起動フラグのプロバイダー
final firstLaunchProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return prefs.getBool('first_launch') ?? true;
});

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

// Firebase 初期化を管理するプロバイダー
final firebaseInitializationProvider = FutureProvider<void>((ref) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初期化はアプリの起動時に行います
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 初回起動状態
    final firstLaunch = ref.watch(firstLaunchProvider);
    // デバイス情報
    final deviceInfo = ref.watch(deviceInfoProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BatterySync',
      themeMode: ThemeMode.system,
      theme: ThemeData.light(
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ),

      // 初回起動の場合はIntroductionPageになり、でなければListPageになる
      home: firstLaunch.when(
        data: (firstLaunch) => firstLaunch ? const IntroductionPage() : const ListPage(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(child: Text('Error loading data')),
      ),
    );
  }
}