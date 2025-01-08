/// Flutter関係のインポート
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter/services.dart'; // システム設定取得用
import 'dart:async';

/// Firebase関係のインポート
import 'package:firebase_auth/firebase_auth.dart';

/// その他インポート
import 'package:package_info_plus/package_info_plus.dart'; // 情報取得用パッケージ
import 'package:settings_ui/settings_ui.dart'; // 設定画面UI設計用パッケージ

import 'login.dart';

/// プロバイダーの設定
final userEmailProvider = StateProvider<String>((ref) => 'サインインしていません');
final versionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
});

/// ページ設定
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends ConsumerState<SettingsPage> {
  late final StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    // ユーザー情報の取得
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) { // ウィジェットが破棄されていない場合のみ状態を更新
        ref.read(userEmailProvider.notifier).state =
            user?.email ?? 'サインインしていません';
      }
    });
  }

  @override
  void dispose() {
    // リスナーを解除
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 非同期での設定情報取得
    final versionAsync = ref.watch(versionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          '設定',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontSize: 25
          )
        ),
      ),
      body: versionAsync.when(
        data: (version) {
          return SettingsList(
            lightTheme: SettingsThemeData(
              settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
            ),
            darkTheme: SettingsThemeData(
              settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
            ),
            sections: [
              /*
              SettingsSection(
                title: const Text('ユーザー設定'),
                  tiles: <SettingsTile>[

                  ]
              ),*/
              SettingsSection(
                title: const Text('マイアカウント'),
                tiles: <SettingsTile>[
                  SettingsTile(
                    leading: const Icon(Icons.account_circle_rounded),
                    title: const Text('アカウント情報'),
                    value: Text(ref.watch(userEmailProvider)),
                  ),
                  SettingsTile.navigation(
                    leading: const Icon(Icons.login),
                    title: const Text('サインイン'),
                    onPressed: (context) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) {
                          return const LoginPage();
                        }),
                      );
                    }
                  )
                ]
              ),
              SettingsSection(
                title: const Text('情報'),
                tiles: <SettingsTile>[
                  SettingsTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('バージョン'),
                    value: Text(version)
                  ),
                ]
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}