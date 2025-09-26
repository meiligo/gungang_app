import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// =========================[ 1) 활동 점수 계산기 ]=========================
class ActivityScoreConfig {
  final double targetDpm;   // cm/min (기본 600 = 6 m/min)
  final double targetSpeed; // cm/s   (기본 6 cm/s)
  final double wDpm;        // DPM 가중치
  final double wSpeed;      // 속도 가중치

  const ActivityScoreConfig({
    this.targetDpm = 600.0,
    this.targetSpeed = 6.0,
    this.wDpm = 0.7,
    this.wSpeed = 0.3,
  });
}

enum AgeGroup { infant, adolescent, young, middle, senior }

class ActivityScoreResult {
  final double totalDistanceCm;
  final double durationSec;
  final double distancePerMinute; // cm/min
  final double avgSpeed;          // cm/s
  final double baseScore;         // 0~100
  final double ageAdj;            // -10~+10
  final double score;             // 0~100
  final String level;             // 등급
  final AgeGroup ageGroup;

  const ActivityScoreResult({
    required this.totalDistanceCm,
    required this.durationSec,
    required this.distancePerMinute,
    required this.avgSpeed,
    required this.baseScore,
    required this.ageAdj,
    required this.score,
    required this.level,
    required this.ageGroup,
  });
}

class ActivityScorer {
  static double _clamp(double v, double min, double max) =>
      v < min ? min : (v > max ? max : v);

  static double _normByTarget(double value, double target) {
    if (target <= 0) return 0;
    return _clamp(value / target, 0, 1) * 100.0;
  }

  // DOB → 연령대
  static AgeGroup classifyAgeGroup(DateTime dob, {DateTime? today}) {
    final now = today ?? DateTime.now().toUtc();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;

    if (months <= 6) return AgeGroup.infant;
    if (months <= 24) return AgeGroup.adolescent;
    if (months <= 72) return AgeGroup.young;
    if (months <= 120) return AgeGroup.middle;
    return AgeGroup.senior;
  }

  static String labelLevel(double score) {
    if (score >= 80) return '매우 활동적';
    if (score >= 60) return '활동적';
    if (score >= 30) return '보통';
    return '저활동';
  }

  // DB 레코드 기반 계산(거리 m, 시작/종료 시각)
  static ActivityScoreResult computeFromRecord({
    required double distanceMeters,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime catDob,
    ActivityScoreConfig config = const ActivityScoreConfig(),
  }) {
    final durationSec = (endTime.toUtc().difference(startTime.toUtc()).inMilliseconds) / 1000.0;
    final distanceCm = (distanceMeters.isFinite && distanceMeters > 0) ? distanceMeters * 100.0 : 0.0;

    return compute(
      distanceCm: distanceCm,
      durationSec: durationSec <= 0 ? 1 : durationSec,
      catDob: catDob,
      config: config,
    );
  }

  // 핵심 계산(거리 cm, 시간 s)
  static ActivityScoreResult compute({
    required double distanceCm,
    required double durationSec,
    required DateTime catDob,
    ActivityScoreConfig config = const ActivityScoreConfig(),
  }) {
    if (!distanceCm.isFinite || distanceCm < 0) distanceCm = 0;
    if (!durationSec.isFinite || durationSec <= 0) durationSec = 1;

    final dpm = distanceCm / (durationSec / 60.0); // cm/min
    final v   = distanceCm / durationSec;          // cm/s

    final a = _normByTarget(dpm, config.targetDpm);   // DPM 점수
    final s = _normByTarget(v,   config.targetSpeed); // 속도 점수
    final base = config.wDpm * a + config.wSpeed * s;

    // 연령 보정
    final group = classifyAgeGroup(catDob);
    double ageAdj = 0.0;
    switch (group) {
      case AgeGroup.infant:
        if (s < 50) ageAdj += _clamp((50 - s) * 0.20, 0, 10);
        if (s > 90) ageAdj -= _clamp((s - 90) * 0.15, 0, 5);
        break;
      case AgeGroup.adolescent:
        if (s < 60) ageAdj += _clamp((60 - s) * 0.25, 0, 10);
        break;
      case AgeGroup.young:
        ageAdj = 0;
        break;
      case AgeGroup.middle:
        if (a < 60) ageAdj += _clamp((60 - a) * 0.20, 0, 8);
        if (s > 90) ageAdj -= _clamp((s - 90) * 0.20, 0, 5);
        break;
      case AgeGroup.senior:
        if (a < 60) ageAdj += _clamp((60 - a) * 0.25, 0, 10);
        if (s > 80) ageAdj -= _clamp((s - 80) * 0.25, 0, 7);
        break;
    }

    final score = _clamp(base + ageAdj, 0, 100);
    final level = labelLevel(score);

    return ActivityScoreResult(
      totalDistanceCm: distanceCm,
      durationSec: durationSec,
      distancePerMinute: dpm,
      avgSpeed: v,
      baseScore: base,
      ageAdj: ageAdj,
      score: score,
      level: level,
      ageGroup: group,
    );
  }
}

// =========================[ 2) DB 레코드 모델 + API ]=========================
// Mongo 문서 → 앱 모델
class ActivityRecord {
  final double distanceMeters; // DB: "distance" (m)
  final DateTime startTime;    // DB: "start_time"
  final DateTime endTime;      // DB: "end_time"

  ActivityRecord({
    required this.distanceMeters,
    required this.startTime,
    required this.endTime,
  });

  factory ActivityRecord.fromMongo(Map<String, dynamic> doc) {
    final dist = (doc['distance'] as num?)?.toDouble() ?? 0.0;
    final start = DateTime.parse(doc['start_time']); // ISO8601
    final end   = DateTime.parse(doc['end_time']);
    return ActivityRecord(distanceMeters: dist, startTime: start, endTime: end);
  }
}
Future<double?> fetchLatestWeight({String? detectionId}) async {
  try {
    final query = detectionId != null ? '?detection_id=$detectionId' : '';
    final url = Uri.parse('http://192.168.100.130:3000/api/health/body/weight/latest$query');

    debugPrint("[체중 API 요청] $url");  // 요청 URL 로그

    final res = await http.get(url);

    debugPrint("[응답 코드] ${res.statusCode}");
    debugPrint("[응답 바디] ${res.body}");

    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final weight = (data['weight'] as num?)?.toDouble();

    debugPrint("[최신 체중] $weight kg");  // 변환된 체중 로그
    return weight;
  } catch (e) {
    debugPrint("체중 불러오기 실패: $e");
    return null;
  }
}


// 최신 1건 가져오기(API는 단일 문서를 반환한다고 가정)
Future<ActivityRecord?> fetchLatestActivityRecord() async {
  // TODO: 최신 1건 반환하는 엔드포인트로 교체
  final url = Uri.parse('http://192.168.100.130:3000/api/activities/catTest/latest');
  final res = await http.get(url);
  if (res.statusCode != 200) return null;
  final data = jsonDecode(res.body) as Map<String, dynamic>;
  return ActivityRecord.fromMongo(data);
}

// =========================[ 3) AI 급식 설정 페이지 ]=========================
class AiFeedSettingPage extends StatefulWidget {
  @override
  _AiFeedSettingPageState createState() => _AiFeedSettingPageState();
}

class _AiFeedSettingPageState extends State<AiFeedSettingPage> {
  double? _currentWeight;            // kg
  double? _recommendedAmount;        // g/day
  int _activityScore = 82;           // 0~100 (prefs/DB에서 갱신)
  double _kcalPer100g = 350;         // kcal/100g (prefs에서 갱신 가능)
  bool _loading = true;

  // ====== 급식량 계산 (선형표 + 활동 보정) ======
  double _calcRER(double wKg) => 70.0 * pow(wKg, 0.75);

  double _factorFromScore(int score) {
    if (score <= 40) return 0.8;
    if (score <= 60) return 1.0;
    if (score <= 80) return 1.2;
    return 1.4;
  }

  double _calculateRecommended(double weightKg, int activityScore, double kcalPer100g) {
    double interpolate(double x, double x1, double y1, double x2, double y2) {
      if (x <= x1) return y1;
      if (x >= x2) return y2;
      return y1 + (x - x1) * (y2 - y1) / (x2 - x1);
    }

    double baseGrams;
    if (weightKg <= 3.0) {
      baseGrams = 70;
    } else if (weightKg <= 4.0) {
      baseGrams = interpolate(weightKg, 3.0, 70, 4.0, 90);
    } else if (weightKg <= 5.0) {
      baseGrams = interpolate(weightKg, 4.0, 90, 5.0, 110);
    } else if (weightKg <= 6.0) {
      baseGrams = interpolate(weightKg, 5.0, 110, 6.0, 120);
    } else {
      baseGrams = 120 + (weightKg - 6.0) * 5; // 6kg 초과: +5g/kg
    }

    final activityFactor = _factorFromScore(activityScore); // 0.8~1.4
    final adjusted = baseGrams * activityFactor;

    double roundTo(double v, double multiple) => (v / multiple).round() * multiple;
    return roundTo(adjusted.clamp(10.0, 300.0), 6); // 6g 단위 반올림
  }

  // ====== 서버에 급식량 전송 ======
  Future<void> setAutoFeedingAmount(double amount) async {
    final url = Uri.parse('http://192.168.100.130:3000/feeding-command'); // TODO: 확인
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'daily_amount_g': amount}), // ✅ 전달 인자 사용(버그 수정)
    );

    if (response.statusCode == 200) {
      debugPrint('급식량 설정 성공: ${amount}g');
      debugPrint('서버 응답: ${response.body}');
    } else {
      debugPrint('급식량 설정 실패: ${response.statusCode}');
      debugPrint('서버 응답: ${response.body}');
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint("[BOOTSTRAP 시작]");

    // 1) 로컬 저장된 값 로드
    final savedWeight = prefs.getDouble('_catWeight');
    final savedScore  = prefs.getInt('activityScore');
    final savedKcal   = prefs.getDouble('kcalPer100g');
    if (savedScore != null) _activityScore = savedScore.clamp(0, 100);
    if (savedKcal != null && savedKcal > 0) _kcalPer100g = savedKcal;

    // 2) DB에서 최신 활동 레코드 가져오기 (기존 코드 유지)
    final dob = DateTime(2016, 3, 15); // TODO: 실제 DOB로 교체
    final latest = await fetchLatestActivityRecord();
    if (latest != null) {
      final result = ActivityScorer.computeFromRecord(
        distanceMeters: latest.distanceMeters,
        startTime: latest.startTime,
        endTime: latest.endTime,
        catDob: dob,
      );
      _activityScore = result.score.round();
      await prefs.setInt('activityScore', _activityScore);
    }

    // 3) ✅ DB에서 최신 체중 가져오기 (없으면 로컬 저장값 사용)
    final dbWeight = await fetchLatestWeight();
    _currentWeight = dbWeight ?? savedWeight ?? 3.0;

    // 4) 추천 급식량 계산
    _recommendedAmount = _calculateRecommended(_currentWeight!, _activityScore, _kcalPer100g);

    // 5) (선택) 서버로 전송
    await setAutoFeedingAmount(_recommendedAmount!);

    if (mounted) setState(() => _loading = false);

    _currentWeight = dbWeight ?? savedWeight ?? 3.0;

    debugPrint("[최종 선택된 체중] $_currentWeight kg");
    debugPrint("[활동 점수] $_activityScore 점");

    _recommendedAmount = _calculateRecommended(_currentWeight!, _activityScore, _kcalPer100g);
    debugPrint("[추천 급식량] $_recommendedAmount g/day");

    await setAutoFeedingAmount(_recommendedAmount!);

    if (mounted) setState(() => _loading = false);
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
            'AI 급식',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              // 체중
              const Text('현재 체중', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                _currentWeight != null ? '${_currentWeight!.toStringAsFixed(1)} kg' : '로딩 중...',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('현재 정상체중 입니다.', style: TextStyle(fontSize: 18)),

              const SizedBox(height: 30),

              // 활동 점수
              const Text('활동량 점수', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                '$_activityScore 점',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              // 추천 급식량
              const Text('일일 AI 추천 급식량', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                _recommendedAmount != null ? '${_recommendedAmount!.toStringAsFixed(0)} g' : '계산 중...',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5f33e1),
                ),
              ),
              SizedBox(height: 100,),
          Align(
            alignment: Alignment.centerLeft, // **왼쪽 정렬 핵심 코드**
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                // AI 추천 급식 기준 섹션
                Text(
                  '* AI 추천 급식 기준',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff5f33e1),
                  ),
                ),
                Text(
                  ' 현재 체중과 생애주기 보정, 활동량 보정값을 활용하여 급식량 계산합니다.',
                  style: TextStyle(
                      fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff5f33e1)),
                ),
                // 초기 권장 칼로리 산식 섹션
                Text(
                  '* 초기 권장 칼로리 산식 : 수의 영양 가이드 - RER/MER',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff5f33e1),
                  ),
                ),

                // 생애주기 구분 섹션
                Text(
                  '* 생애주기 구분은 AAFP/AAHA 고양이 생애 단계 가이드라인을 따릅니다.',
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff5f33e1),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

