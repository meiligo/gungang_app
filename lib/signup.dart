import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();


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

  void _signup() async {
    final email = _emailController.text;
    final name = _nameController.text;
    final phone = _phoneController.text;
    final password = _passwordController.text;

    final url = Uri.parse('http://192.168.100.130:3000/users/signup');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'phone_number': phone,
        }),
      );
      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');


      if (response.statusCode == 200) {
        // 회원가입 성공
        final result = jsonDecode(response.body);
        print('회원가입 성공: ${result['message']}');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('성공'),
            content: Text('회원가입이 완료되었습니다!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          ),
        );
      } else {
        // 실패
        final result = jsonDecode(response.body);
        print('회원가입 실패: ${result['error']}');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('실패'),
            content: Text('회원가입에 실패했습니다.\n${result['error']}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('에러 발생: $e');
    }
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('회원가입', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일을 입력해주세요',
                  labelStyle: TextStyle(
                    color: Colors.black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
              ),
              SizedBox(height: 30),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                    labelText: '이름를 입력해주세요',
                  labelStyle: TextStyle(
                    color: Colors.black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
              ),
              SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: '전화번호를 입력해주세요',
                  labelStyle: TextStyle(
                      color: Colors.black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
              ),
              SizedBox(height: 30),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: '비밀번호를 입력해주세요',
                  labelStyle: TextStyle(
                      color: Colors.black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
              ),
              SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: '비밀번호 중복 확인',
                  labelStyle: TextStyle(
                      color: Colors.black
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xff5f33e1), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                cursorColor: Colors.black,
                onChanged: (_) => _checkPasswordMatch(),
              ),
              SizedBox(height: 5),
              Text(
                _passwordMessage,
                style: TextStyle(
                  color: _passwordMessage.contains('일치합니다') ? Colors.green : Colors.red,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signup,
                child: Text('회원가입',
                style: TextStyle(color: Colors.white, fontSize: 25),
                ),
                style:
                ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Color(0xff5f33e1),
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
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

}
