import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
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
            'lib/assets/set_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 26, // 아이콘 크기 조절
            height: 26,
          ),
          const SizedBox(width: 3), // 아이콘과 텍스트 사이 간격
          const Text(
            '설정',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
        leading: IconButton(
          // 뒤로가기 버튼 (기본적으로 생기지만 명시적으로 추가해도 좋아)
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),

      body: Padding(
        // 전체적으로 약간의 여백 주기
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          // 버튼들을 세로로 나열
          crossAxisAlignment: CrossAxisAlignment.stretch, // 버튼 너비 최대로 채우기
          children: <Widget>[
            SizedBox(height: 120), // 버튼 사이 간격
            _buildSettingsButton(
              context: context,
              label: '비밀번호 변경',
              onPressed: () {
                Navigator.pushNamed(context, '/usersetting');
                print('비밀번호 변경 버튼 클릭됨');
              },
            ),
            SizedBox(height: 40), // 버튼 사이 간격
            _buildSettingsButton(
              context: context,
              label: '고양이 정보 수정',
              onPressed: () {
                Navigator.pushNamed(context, '/catinfoedit');
                print('고양이 정보 수정 버튼 클릭됨');
              },
            ),
            SizedBox(height: 40), // 버튼 사이 간격
            _buildSettingsButton(
              context: context,
              label: '어플리케이션 설정',
              onPressed: () {
                Navigator.pushNamed(context, '/appsetting');
                print('어플리케이션 설정 버튼 클릭됨');
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  // 설정 메뉴 버튼을 만드는 함수 (코드 중복 줄이기용)
  Widget _buildSettingsButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label, style: TextStyle(fontSize: 20, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 20),
        backgroundColor: Color(0xff5f33e1),
        shape: RoundedRectangleBorder(
          // 약간 둥근 모서리
          borderRadius: BorderRadius.circular(12),
        ),
        // primary: Colors.grey[200], // 버튼 배경색 (원하는 색으로 변경 가능)
        // onPrimary: Colors.black, // 버튼 글자색 (원하는 색으로 변경 가능)
      ),
    );
  }
}
