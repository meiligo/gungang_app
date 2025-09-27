import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'feed_record.dart';
import 'dart:convert';

class SelfFeedingPage extends StatefulWidget {
  @override
  _SelfFeedingPageState createState() => _SelfFeedingPageState();
}



class _SelfFeedingPageState extends State<SelfFeedingPage> {
  double _selectedAmount = 0; // 초기 사료량 (g)
  String _catWeight  = '3.0';

  Future<void> onManualFeedSuccess(double gramsDispensed) async {
    final rec = FeedRecord(
      timestamp: DateTime.now(),
      amount: gramsDispensed,
      mode: FeedMode.manual,
    );

    await LocalFeedStore.add(rec);     // ✅ 로컬에 즉시 저장
    // 필요하면 결과를 호출자에게 알려주기 (선택)
    if (Navigator.canPop(context)) {
      Navigator.pop(context, rec.toJson());
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCatData();
  }

// 수정된 _loadCatData() 함수
  Future<void> _loadCatData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) throw Exception('저장된 사용자 ID 없음');

      // ✅ 활동 기록이 아닌 '체중' 정보를 가져오는 URL로 수정
      final url = Uri.parse('http://192.168.100.130:3000/api/health/body/weight/latest');
      final response = await http.get(url);

      print('sdfsdfsdfsdfs ${url}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("서버 응답 데이터: $data");

        double? weight = (data['weight'] as num?)?.toDouble();
        String weightStr = weight != null
            ? '${weight.toStringAsFixed(1)}'
            : '몸무게 정보 없음';

        if (mounted) {
          setState(() {
            _catWeight = weightStr;
          });
          if (weight != null) {
            await prefs.setDouble('_catWeight', weight);
          }
        }
      } else {
        throw Exception("서버 응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("고양이 정보 로드 에러: $e");

    }
  }


  String _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int years = today.year - birthDate.year;
    int months = today.month - birthDate.month;
    int days = today.day - birthDate.day;

    if (months < 0 || (months == 0 && days < 0)) {
      years--;
      months += (days < 0 ? 11 : 12);
    }

    if (years > 0) {
      return "$years살";
    } else if (months > 0) {
      return "$months개월";
    } else {
      return "1살 미만";
    }
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
            '수동 급식',
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
            SizedBox(height: 15,),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 18, color: Colors.black), // 기본 스타일
                children: [
                  const TextSpan(text: '현재 체중 :  '),
                  TextSpan(
                    text: _catWeight, // 이 부분만 스타일 다르게
                    style: const TextStyle(
                      fontSize: 22, // 더 크게
                      fontWeight: FontWeight.bold,
                      color: Color(0xff5f33e1), // 파란색
                    ),
                  ),
                  const TextSpan(text: ' kg'),
                ],
              ),
            ),

            SizedBox(height: 6,),
            Text('상태 : 정상 범위',style: TextStyle(fontSize: 18),),
            SizedBox(height: 20,),
            Text('급식할 사료량을 선택하세요', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('${_selectedAmount.toStringAsFixed(1)} g',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 150,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                    initialItem: (_selectedAmount / 6).toInt()),
                itemExtent: 40,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedAmount = index * 6; // 6g 단위
                  });
                },
                children: List<Widget>.generate(21, (index) {
                  return Center(child: Text('${(index * 6).toStringAsFixed(1)} g'));
                }),
              ),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedAmount <= 0)
                    ? null                       // ✅ 0g이거나 로딩 중이면 비활성화
                    : () async {
                  try {
                  final url = Uri.parse("http://192.168.100.9:5000/feed"); // 서버 주소
                  final response = await http.post(
                    url,
                    headers: {'Content-Type': 'application/json'}, // 🔥 이게 중요!
                    body: jsonEncode({
                      'amount': _selectedAmount.toStringAsFixed(1),
                      'token': 'change-me-strong-token'
                    }),
                  );
                  if (!mounted) return;
                  if (response.statusCode == 200) {
                    print('$_selectedAmount g 급식 성공!');

                    final rec = FeedRecord(
                      timestamp: DateTime.now(),
                      amount: _selectedAmount,
                      mode: FeedMode.manual, // 수동급식
                    );
                    await LocalFeedStore.add(rec);

                    print("로컬 급식 이력에 저장됨: ${rec.toJson()}");
                  } else {
                    print('서버 오류: ${response.statusCode}, 응답 : ${response.body}');
                  }
                } catch (e) {
                    print('에러 발생: $e');
                }
                  print('수동 급식 실행: $_selectedAmount g');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$_selectedAmount g 급식 명령 전송됨')),
                  );
                },
                child: Text('수동 급식', style: TextStyle(fontSize: 20, color: Colors.white),),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff5f33e1),
                  padding: EdgeInsets.symmetric(vertical: 16),

                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
