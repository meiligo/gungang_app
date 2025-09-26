import 'package:flutter/material.dart';

class UserSettings extends StatefulWidget {
  @override
  _UserSettingsState createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String _passwordMessage = '';

  void _checkPasswordMatch() {
    setState(() {
      if (_passwordController.text == _confirmPasswordController.text) {
        _passwordMessage = '비밀번호가 일치합니다.';
      } else {
        _passwordMessage = '비밀번호가 일치하지 않습니다.';
      }
    });
  }

  void _changePassword() {
    if (_passwordController.text == _confirmPasswordController.text) {
      print('비밀번호 변경: ${_passwordController.text}');
      // 비밀번호 변경 로직 (서버 연동 등)
    } else {
      print('비밀번호 불일치');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      title: Row(
        mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 최소화
        children: [
          Image.asset(
            'lib/assets/set_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '비밀번호 변경',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호를 입력해주세요.',
                labelStyle: TextStyle(color: Colors.black),
                fillColor: Colors.white,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              cursorColor: Colors.black,
              onChanged: (_) => _checkPasswordMatch(),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호 중복 확인',
                labelStyle: TextStyle(color: Colors.black),
                fillColor: Colors.white,
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              cursorColor: Colors.black,
              onChanged: (_) => _checkPasswordMatch(),
            ),
            SizedBox(height: 10),
            Text(
              _passwordMessage,
              style: TextStyle(
                color: _passwordMessage.contains('일치합니다') ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff5f33e1),
                foregroundColor: Colors.white, // 글자색 흰색
                textStyle: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                padding: EdgeInsets.symmetric(vertical: 20.0), // 버튼 내부 세로 여백
                shape: RoundedRectangleBorder( // 모서리 거의 없이
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/');
              },
              child: Text('수동 급식'),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
