import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';



class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}



class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이디와 비밀번호를 모두 입력해주세요!')),
      );
      return;
    }

    final url = Uri.parse('http://192.168.100.130:3000/users/login'); // 서버 IP로 수정
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        final result = jsonDecode(response.body);
        final user = result['user']; // ✅ user 정보 전체
        // ✅ 로그인 상태 저장
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('username', username);
        await prefs.setString('userId', user['_id']);

        final userId = user['_id'];
        await prefs.setString('userId', userId);

// 🎯 고양이 등록 여부 서버에서 확인
        final catResponse = await http.get(
          Uri.parse('http://192.168.100.130:3000/api/cats/$userId'),
        );

        print("상태 코드: ${catResponse.statusCode}");
        print("응답 헤더: ${catResponse.headers}");
        print("응답 본문: ${catResponse.body}");

        if (catResponse.statusCode == 200) {
          final catData = jsonDecode(catResponse.body);

          if (catData is List && catData.isNotEmpty) {
            await prefs.setBool('isCatRegistered', true);
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            await prefs.setBool('isCatRegistered', false);
            Navigator.pushReplacementNamed(context, '/catregister');
          }
        } else {
          // 서버에서 고양이 정보 못 불러왔을 때
          Navigator.pushReplacementNamed(context, '/catregister');
        }

      } else {
        final result = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: ${result['error']}')),
        );
      }
    }on SocketException catch (e) {
      // 보통: 서버 다운, 포트 차단, 잘못된 IP/포트, 바인딩 127.0.0.1 등
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('소켓 연결 실패: ${e.osError?.message ?? e.message}')),
      );
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청 시간 초과 (서버 응답 없음)')),
      );
    } on HandshakeException catch (e) {
      // HTTPS 이슈일 때; 지금은 http라 드물지만 혹시 모름
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TLS/인증서 오류: ${e.message}')),
      );
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 연결 실패: $e')),
      );
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
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0), // 이미지 위쪽 여백
        child: Scaffold(
          backgroundColor: Colors.transparent, // Scaffold의 배경을 투명하게 설정
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(''),
            automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  'lib/assets/cat.png',
                  width: 200,
                  height: 200,
                ),
                SizedBox(height: 20),
                Text(
                  'AI 헬스케어 급식기',
                  style: TextStyle(fontSize: 20, color: Color(0xff4a4a4a)),
                ),
                Text(
                  '건강하냥',
                  style: TextStyle(
                    color: Color(0xff4a4a4a),
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30),

                // 🔹 사용자 아이디 입력 박스
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '사용자 아이디',
                      labelStyle: TextStyle(
                        color: Color(0xffaaaaaa),
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none, // 테두리 제거
                      ),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    cursorColor: Colors.black,
                  ),
                ),

                SizedBox(height: 20),

                // 🔹 비밀번호 입력 박스
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      labelStyle: TextStyle(
                        color: Color(0xffaaaaaa),
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none, // 테두리 제거
                      ),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    cursorColor: Colors.black,
                  ),
                ),

                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _login,
                  child: Text(
                    '로그인',
                    style: TextStyle(color: Colors.white, fontSize: 21),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff5f33e1),
                    minimumSize: Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/signup');
                    print('회원가입 버튼 클릭됨');
                  },
                  child: Text(
                    '회원가입',
                    style: TextStyle(
                      color: Color(0xff5f33e1),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xff5f33e1),
                      decorationThickness: 1.5,
                    ),
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
    // 페이지가 없어질 때 컨트롤러 정리
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
