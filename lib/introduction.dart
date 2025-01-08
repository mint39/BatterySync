import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overboard/flutter_overboard.dart';
import 'device_list.dart';

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({super.key});

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {

  _afterIntroduction() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
    Navigator.pushAndRemoveUntil( context,
        MaterialPageRoute(builder: (context) => const ListPage()), (_) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: OverBoard(
          pages: pages,
          showBullets: true,
          skipCallback: () {
            // SKIPを押した時の動作
            _afterIntroduction();
          },
          finishCallback: () {
            // FINISHを押した時の動作
            _afterIntroduction();
          },
        ),
      )
    );
  }

  final pages = [
    PageModel(
      color: const Color(0xFF95cedd),
      imageAssetPath: 'assets/imgs/icon.png',
      title: 'BatterySync',
      body: '複数端末のバッテリー残量を一元管理できます。',
      doAnimateImage: true
    ),
    PageModel.withChild(
      child: const Padding(
          padding: EdgeInsets.only(bottom: 25.0),
          child: Text('さあ、始めましょう！', style: TextStyle(color: Colors.white, fontSize: 32))),
      color: const Color(0xFF5886d6),
      doAnimateChild: true
    )
  ];
}