import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MoveAnalyze extends StatefulWidget {
  const MoveAnalyze({Key? key}) : super(key: key);

  @override
  State<MoveAnalyze> createState() => _MoveAnalyzeState();
}

class _MoveAnalyzeState extends State<MoveAnalyze> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSystemLogs();
  }

  Future<void> fetchSystemLogs() async {
    final url = Uri.parse(
      // 1) 서버가 단일 객체를 주는 /latest 엔드포인트가 있다면 그걸 쓰세요.
      // 'http://192.168.100.130:3000/api/activities/catTest/latest'
      // 2) 아직 목록을 주는 기존 엔드포인트만 있다면 아래 줄 유지
        'http://192.168.100.130:3000/api/activities/catTest');

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _logs = [];
          _isLoading = false;
        });
        return;
      }

      final body = json.decode(response.body);

      // body가 "단일 객체(Map)" or "목록(List)"인지에 따라 마지막 1개를 고정 선택
      Map<String, dynamic>? lastItem;
      if (body is Map<String, dynamic>) {
        // 서버가 이미 마지막 1개만 준 케이스 (/latest)
        lastItem = body;
      } else if (body is List && body.isNotEmpty) {
        // 서버가 목록을 준 케이스: 마지막 요소만 사용
        final dynamic tail = body.last;
        if (tail is Map<String, dynamic>) lastItem = tail;
      }

      if (lastItem == null) {
        if (!mounted) return;
        setState(() {
          _logs = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> collected = [];
      final List<dynamic>? sys = lastItem['system_logs'] as List<dynamic>?;

      if (sys != null) {
        for (final line in sys) {
          final parts = line.toString().split(',');
          for (final p in parts) {
            final s = p.trim();
            if (s.isEmpty) continue;

            if (s.contains("분석 및 결과 저장이 완료되었습니다.")) {
              // 이 메시지는 5초 지연 후에 추가
              Future.delayed(const Duration(seconds: 5), () {
                if (!mounted) return;
                setState(() {
                  _logs.add({"message": s});
                });
              });
            } else {
              collected.add({"message": s});
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _logs = collected;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logs = [];
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    const consoleTextStyle = TextStyle(
      fontFamily: 'monospace',
      color: Colors.greenAccent,
      fontSize: 14,
    );

    return Scaffold(
      backgroundColor: Colors.black, // CMD 스타일 배경
      appBar: AppBar(
        title: const Text('활동량 분석 로그', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(
        child: Text(
          '로그가 없습니다.',
          style: consoleTextStyle,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          final message = (log['message'] ?? '').toString();

          // 특정 메시지 뒤에 "빈 공간(영상 자리)" 플레이스홀더 삽입
          if (message == "영상 리소스 해제 완료.") {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("> $message", style: consoleTextStyle),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.greenAccent),
                    ),
                    child: const Text(
                      '영상 플레이어 제거됨\n(플레이스홀더 영역)',
                      textAlign: TextAlign.center,
                      style: consoleTextStyle,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }

          // 기본 로그
          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text("> $message", style: consoleTextStyle),
          );
        },
      ),
    );
  }
}
