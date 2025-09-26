import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


enum FeedMode { auto, manual }

class FeedRecord {
  final DateTime timestamp; // 급식 시간
  final double amount;      // g
  final FeedMode mode;      // 수동/자동

  FeedRecord({required this.timestamp, required this.amount, required this.mode});

  factory FeedRecord.fromJson(Map<String, dynamic> j) => FeedRecord(
    timestamp: DateTime.parse(j['timestamp']),
    amount: (j['amount'] as num).toDouble(),
    mode: (j['mode'] == 'manual') ? FeedMode.manual : FeedMode.auto,
  );

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'amount': amount,
    'mode': mode == FeedMode.manual ? 'manual' : 'auto',
  };
}




class LocalFeedStore {
  static const _key = 'feed_history_v1';

  static Future<List<FeedRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final List data = jsonDecode(raw);
    return data.map((e) => FeedRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<FeedRecord> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> add(FeedRecord rec) async {
    final list = await load();
    list.insert(0, rec); // 최신 맨 위
    await save(list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}


class FeedRecordPage extends StatefulWidget {
  @override
  _FeedRecordPageState createState() => _FeedRecordPageState();
}

class _FeedRecordPageState extends State<FeedRecordPage> {
  List<FeedRecord> _feedHistory = []; // 급식 이력 데이터 리스트
  bool _isLoading = true; // 로딩 상태

  @override
  void initState() {
    super.initState();
    _fetchFeedHistory(); // 화면 시작 시 데이터 로드
  }


  // --- 서버에서 급식 이력 가져오는 함수 (Placeholder) ---
  Future<void> _fetchFeedHistory() async {
    setState(() => _isLoading = true);
    final list = await LocalFeedStore.load();
    // 이미 add시 최신이 앞에 오게 넣지만, 혹시 모를 정렬
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _feedHistory = list;
      _isLoading = false;
    });
  }

  Future<void> _goToSelfFeeding() async {
    final result = await Navigator.pushNamed(context, '/self_feeding');
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      final rec = FeedRecord.fromJson(result);
      setState(() => _feedHistory.insert(0, rec)); // 화면 즉시 반영
      await LocalFeedStore.add(rec);               // 영구 저장
    } else {
      // result를 안 돌려줘도 괜찮다면 로컬 저장된 걸 다시 로드
      await _fetchFeedHistory();
    }
  }



  // --- 날짜 포맷 함수 ---
  String _formatDate(DateTime dt) {
    return DateFormat('M월 d일', 'ko_KR').format(dt); // 예: 4월 6일
  }

  // --- 시간 포맷 함수 ---
  String _formatTime(DateTime dt) {
    // 'a'는 오전/오후, 'hh'는 12시간 기준 시, 'mm'은 분
    return DateFormat('a hh:mm', 'ko_KR').format(dt); // 예: 오후 12:30
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
            '급식 이력',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // 로딩 중
          : _feedHistory.isEmpty
          ? Center(child: Text('급식 기록이 없습니다.')) // 데이터 없음
          : ListView.separated( // 각 항목 사이에 구분선 추가
        itemCount: _feedHistory.length,
        itemBuilder: (context, index) {
          final record = _feedHistory[index];
          return _buildFeedRecordItem(record); // 각 항목 위젯 생성
        },
        separatorBuilder: (context, index) => Divider( // 구분선
          height: 1, // 높이 1
          thickness: 1, // 두께 1
          color: Colors.grey[200], // 연한 회색
          indent: 16, // 왼쪽 여백
          endIndent: 16, // 오른쪽 여백
        ),
      ),
    ),
    );
  }

  // --- 급식 이력 항목 위젯 생성 함수 ---
  Widget _buildFeedRecordItem(FeedRecord record) {
    final bool isManual = record.mode == FeedMode.manual;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), // 내부 여백 조절

      leading: Chip(
        label: Text(isManual ? '수동' : '자동',
            style: const TextStyle(color: Colors.black, fontSize: 12)),
        backgroundColor: isManual ? Colors.white: Colors.blueGrey,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      title: Text.rich(
        TextSpan(
          text: '사료가 ',
          style: TextStyle(fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
              text: '${record.amount.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xfff3cf0a),
                shadows: [
                  Shadow(
                    offset: Offset(0.7, 0.7),
                    blurRadius: 0.2,
                    color: Colors.grey,
                  )
                ]
              )
            ),
            TextSpan(
              text: ' 급식 되었습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black),
            )
          ]
        )
      ),

      trailing: Column( // 날짜와 시간을 세로로 배치
        mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
        crossAxisAlignment: CrossAxisAlignment.end, // 오른쪽 정렬
        children: [
          Text(
            _formatDate(record.timestamp), // 날짜 표시
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 2), // 날짜와 시간 사이 간격
          Text(
            _formatTime(record.timestamp), // 시간 표시 (오전/오후 포함)
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}