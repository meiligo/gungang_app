import 'package:flutter/material.dart';

class WeightAnalyze extends StatelessWidget {
  const WeightAnalyze({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        // 전체를 Container로 감싸고 배경 이미지 설정
        decoration: const BoxDecoration(
        image: DecorationImage(
        image: AssetImage('lib/assets/bg1.png'), // 이미지 경로
    fit: BoxFit.cover, // 화면에 꽉 차게 설정
    ),
    ),
    child: Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
    backgroundColor: Colors.transparent,
        title: const Text('체중 분석'),
      ),
      body: const Center(
        child: Text(
          '체중 분석 페이지',
          style: TextStyle(fontSize: 18),
        ),
      ),
    ),
    );
  }
}