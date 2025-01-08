/// Flutter関係のインポート
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase関係のインポート
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// その他インポート
import 'settings.dart';
import 'device_list.dart';

/// Authのサインインメッセージ用のprovider
final signInStateProvider = StateProvider((ref) => 'サインインするか、アカウントを作成してください。');

/// ユーザーのサインイン情報用プロバイダー
final userProvider = StateProvider<User?>((ref) => null);
final userEmailProvider = StateProvider<String>((ref) => 'サインインしていません。');

/// サインイン状態管理のプロバイダー
final isSigninProvider = StateProvider<bool>((ref) => false);

/// ページ設定
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends ConsumerState<LoginPage> {
  @override
  void initState() {
    super.initState();

    // FirebaseAuthのサインイン状態を監視し、プロバイダーを更新
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        if (user != null) {
          // サインイン状態の場合
          ref
              .read(userProvider.notifier)
              .state = user;
          ref
              .read(isSigninProvider.notifier)
              .state = true;
          ref
              .read(signInStateProvider.notifier)
              .state = 'アカウントにサインイン済みです。';
        } else {
          // サインアウト状態の場合
          ref
              .read(userProvider.notifier)
              .state = null;
          ref
              .read(isSigninProvider.notifier)
              .state = false;
          ref
              .read(signInStateProvider.notifier)
              .state = 'サインインするか、アカウントを作成してください。';
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget build(BuildContext context) {
    final singInStatus = ref.watch(signInStateProvider);
    final emailController = TextEditingController();
    final passController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
            'サインイン',
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 25
            )
        ),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              /// サインインのメッセージ表示
              Container(
                padding: const EdgeInsets.all(10),
                child: Text(singInStatus),
              ),

              /// メールアドレス入力
              TextField(
                decoration: const InputDecoration(
                  label: Text('メールアドレス'),
                  icon: Icon(Icons.mail),
                ),
                controller: emailController,
              ),

              /// パスワード入力
              TextField(
                decoration: const InputDecoration(
                  label: Text('パスワード'),
                  icon: Icon(Icons.key),
                ),
                controller: passController,
                obscureText: true,
              ),

              /// サインインボタン
              Container(
                margin: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () {
                    /// ログインの場合
                    _signIn(ref, emailController.text, passController.text);
                  },
                  child: const Text('サインイン'),
                ),
              ),

              /// サインアウト
              TextButton(
                  onPressed: () {
                    _signOut(ref);
                  },
                  child: const Text('サインアウト')
              ),

              /// アカウント作成
              Container(
                margin: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () {
                    /// アカウント作成の場合
                    _createAccount(ref, emailController.text, passController.text);
                  },
                  child: const Text('アカウント作成'),
                ),
              ),

              /// Googleログイン
              Container(
                margin: const EdgeInsets.all(10),
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      // Google サインインを実行
                      const googleLogin = GoogleLogin();
                      await googleLogin.signInWithGoogle();

                      // メッセージの更新
                      _googleMessage(ref);

                      // 設定画面に遷移
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SettingsPage()),
                      );

                      // 設定画面に遷移
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      }
                    } catch (e) {
                      rethrow;
                    }
                  },
                  child: const Text('Googleログイン'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// サインイン処理
void _signIn(WidgetRef ref, String id, String pass) async {
  try {
    /// credential にはアカウント情報が記録される
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: id,
      password: pass,
    );

    // サインイン状態を更新
    if (ref.read(isMountedProvider)) {
      ref.read(userProvider.notifier).state = credential.user;
      ref.read(isSigninProvider.notifier).state = true;
      ref.read(signInStateProvider.notifier).state = 'アカウントにサインイン済みです。';
    }

    // サインイン時のFireBaseへの書き込み
    int loginBattery = 0;
    final res = await batteryChannel.invokeMethod('getBatteryInfo');
    loginBattery = res["level"];

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
      'batteryLevel': loginBattery,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// サインインに失敗した場合のエラー処理
  on FirebaseAuthException catch (e) {
    /// メールアドレスが無効の場合
    if (e.code == 'invalid-email') {
      ref.read(signInStateProvider.notifier).state = 'メールアドレスが無効です。';
    }

    /// ユーザーが存在しない場合
    else if (e.code == 'user-not-found') {
      ref.read(signInStateProvider.notifier).state = 'ユーザーが存在しません。';
    }

    /// パスワードが間違っている場合
    else if (e.code == 'wrong-password') {
      ref.read(signInStateProvider.notifier).state = 'パスワードが間違っています。';
    }

    /// その他エラー
    else {
      ref.read(signInStateProvider.notifier).state = 'サインインエラー';
    }
  }
}

/// アカウント作成（mountedに対応するよう要修正）
void _createAccount(WidgetRef ref, String id, String pass) async {
  try {
    /// credential にはアカウント情報が記録される
    final credential =
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: id,
      password: pass,
    );

    /// ユーザ情報の更新
    ref.watch(userProvider.notifier).state = credential.user;

    /// メッセージの更新
    ref.read(signInStateProvider.notifier).state = 'アカウントを作成しました。';
  }

  /// アカウントに失敗した場合のエラー処理
  on FirebaseAuthException catch (e) {
    /// パスワードが弱い場合
    if (e.code == 'weak-password') {
      ref.read(signInStateProvider.notifier).state = 'パスワードが弱いです。';

      /// メールアドレスが既に使用中の場合
    } else if (e.code == 'email-already-in-use') {
      ref.read(signInStateProvider.notifier).state = '既に使用されているメールアドレスです。';
    }

    /// その他エラー
    else {
      ref.read(signInStateProvider.notifier).state = 'アカウント作成エラー';
    }
  } catch (e) {
    print(e);
  }
}

/// サインアウト
void _signOut(WidgetRef ref) async {
  await FirebaseAuth.instance.signOut();
  if (ref.read(isMountedProvider)) {
    ref
        .read(isSigninProvider.notifier)
        .state = false; // ログイン状態を更新
    ref
        .read(signInStateProvider.notifier)
        .state = 'サインインするか、アカウントを作成してください。';
  }
}

/// Googleログイン用メッセージ（mountedに対応するよう要修正）
void _googleMessage(WidgetRef ref) async {
  ref.read(signInStateProvider.notifier).state = 'Googleアカウントでサインイン済みです。';
  ref.watch(isSigninProvider.notifier).state = true; // ログイン状態を更新

  // サインイン時のFireBaseへの書き込み
  int loginBattery = 0;
  final res = await batteryChannel.invokeMethod('getBatteryInfo');
  loginBattery = res["level"];

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
    'batteryLevel': loginBattery,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

/// Googleアカウントログイン処理
class GoogleLogin extends StatelessWidget {
  const GoogleLogin({super.key});

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Google認証フローのトリガー
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // 認証情報の取得
      final GoogleSignInAuthentication? googleAuth =
      await googleUser?.authentication;

      // 認証用の資格情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Firebaseにログイン
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(); // 必要に応じて UI を定義可能
  }
}