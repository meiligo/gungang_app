import 'package:flutter/material.dart';

class FindPassword extends StatefulWidget {
  @override
  _FindPasswordState createState() => _FindPasswordState();
}

class _FindPasswordState extends State<FindPassword> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  void _sendVerificationCode() {
    print('인증번호 전송: ${_phoneController.text}');
  }

  void _verifyCode() {
    print('입력된 인증번호: ${_codeController.text}');
  }

  void _findPassword() {
    print('비밀번호 찾기 요청');
    // Navigator.pushNamed(context, '/change_password'); // 라우트 연결 시 사용
  }

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
        backgroundColor: Colors.transparent, // Scaffold의 배경을 투명하게 설정
        appBar: AppBar(
          backgroundColor: Colors.transparent, // AppBar 배경도 투명하게 설정
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('비밀번호 찾기', style: TextStyle(color: Colors.black)),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '이메일을 입력해주세요',
                    labelStyle: TextStyle(color: Colors.black),
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
                ),
                SizedBox(height: 10),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _findPassword,
                  child: Text('비밀번호 찾기',
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff5f33e1),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
