import 'package:flutter/material.dart';

class FeedSettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
        image: DecorationImage(
        image: AssetImage('lib/assets/bg1.png'), // 이미지 경로
    fit: BoxFit.cover, // 화면에 꽉 차게 설정
    ),
    ),
      child:  Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 최소화
          children: [
            Image.asset(
              'lib/assets/food_icon.png', // 여기에 이미지 경로를 넣어줘
              width: 24, // 아이콘 크기 조절
              height: 24,
            ),
            const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
            const Text(
              '급식 설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Padding( // 전체적으로 약간의 여백을 주자
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // 버튼들을 화면 중앙에 오도록 (위아래로)
          crossAxisAlignment: CrossAxisAlignment.stretch, // 버튼들이 가로로 꽉 차도록
          children: <Widget>[
            // AI 급식 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff5f33e1),
                foregroundColor: Colors.white, // 글자색 흰색
                textStyle: TextStyle(fontSize: 20, ),
                padding: EdgeInsets.symmetric(vertical: 16.0), // 버튼 내부 세로 여백
                shape: RoundedRectangleBorder( // 모서리 거의 없이 (살짝만 둥글게)
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/AI_feeding');
                },
              child: Text('AI  급식'),
            ),

            SizedBox(height: 50), // 버튼 사이 간격 (사진이랑 비슷하게 띄워봤어)

            // 수동 급식 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff5f33e1),
                foregroundColor: Colors.white, // 글자색 흰색
                textStyle: TextStyle(fontSize: 20,),
                padding: EdgeInsets.symmetric(vertical: 16.0), // 버튼 내부 세로 여백
                shape: RoundedRectangleBorder( // 모서리 거의 없이
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/self_feeding');
              },
              child: Text('수동 급식'),
            ),
            SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff5f33e1),
                foregroundColor: Colors.white, // 글자색 흰색
                textStyle: TextStyle(fontSize: 20,),
                padding: EdgeInsets.symmetric(vertical: 16.0), // 버튼 내부 세로 여백
                shape: RoundedRectangleBorder( // 모서리 거의 없이
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/feedrecord');
              },
              child: Text('급식 이력'),
            ),
            SizedBox(height: 100,)
          ],
        ),
      ),
    ),
    );
  }
}