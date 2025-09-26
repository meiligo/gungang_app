import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// =================== Activity Score 계산기 ===================
class ActivityScoreConfig {
  final double targetDpm;   // cm/min
  final double targetSpeed; // cm/s
  final double wDpm;        // 가중치
  final double wSpeed;

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
  final double distancePerMinute;
  final double avgSpeed;
  final double baseScore;
  final double ageAdj;
  final double score;
  final String level;
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

  static AgeGroup classifyAgeGroup(DateTime dob, {DateTime? today}) {
    final now = (today ?? DateTime.now()).toUtc();
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

  static ActivityScoreResult computeFromRecord({
    required double distanceMeters,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime catDob,
    ActivityScoreConfig config = const ActivityScoreConfig(),
  }) {
    final st = startTime.toUtc();
    final et = endTime.toUtc();
    final durationSec = (et.difference(st).inMilliseconds) / 1000.0;
    final distanceCm = distanceMeters > 0 ? distanceMeters * 100.0 : 0.0;

    return compute(
      distanceCm: distanceCm,
      durationSec: durationSec <= 0 ? 1 : durationSec,
      catDob: catDob,
      config: config,
    );
  }

  static ActivityScoreResult compute({
    required double distanceCm,
    required double durationSec,
    required DateTime catDob,
    ActivityScoreConfig config = const ActivityScoreConfig(),
  }) {
    if (distanceCm < 0) distanceCm = 0;
    if (durationSec <= 0) durationSec = 1;

    final dpm = distanceCm / (durationSec / 60.0); // cm/min
    final v   = distanceCm / durationSec;          // cm/s

    final a = _normByTarget(dpm, config.targetDpm);
    final s = _normByTarget(v, config.targetSpeed);
    final base = config.wDpm * a + config.wSpeed * s;

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

// =================== DB 레코드 + API ===================
class ActivityRecord {
  final double distanceMeters;
  final DateTime startTime;
  final DateTime endTime;

  ActivityRecord({
    required this.distanceMeters,
    required this.startTime,
    required this.endTime,
  });

  factory ActivityRecord.fromMongo(Map<String, dynamic> doc) {
    final dist = (doc['distance'] as num?)?.toDouble() ?? 0.0;
    final start = DateTime.parse(doc['start_time']);
    final end   = DateTime.parse(doc['end_time']);
    return ActivityRecord(distanceMeters: dist, startTime: start, endTime: end);
  }
}

class ActivityApi {
  static const String base = 'http://192.168.100.130:3000';
  static const String rangePath  = '/api/activities/catTest';

  static Future<List<ActivityRecord>> fetchRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse(
      '$base$rangePath?start=${start.toUtc().toIso8601String()}&end=${end.toUtc().toIso8601String()}',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((m) => ActivityRecord.fromMongo(Map<String, dynamic>.from(m)))
        .toList();
  }
}

// =================== 분석 요약 생성 ===================
extension _NumFmt on num {
  String toPercent({int fractionDigits = 1}) =>
      '${(this * 100).toStringAsFixed(fractionDigits)}%';
}

class AnalyzeSummary {
  final String avgActivityTimeText;
  final String avgRestIntervalText;
  final String highlightTimeText;
  final String trendText;
  final String activityScoreText;

  const AnalyzeSummary({
    required this.avgActivityTimeText,
    required this.avgRestIntervalText,
    required this.highlightTimeText,
    required this.trendText,
    required this.activityScoreText,
  });
}

AnalyzeSummary buildAnalyzeSummary({
  required List<ActivityRecord> records,
  required DateTime catDob,
}) {
  if (records.isEmpty) {
    return const AnalyzeSummary(
      avgActivityTimeText: '데이터가 부족해요',
      avgRestIntervalText: '평균 0분 쉬었어요',
      highlightTimeText: '데이터가 부족해요',
      trendText: '데이터가 부족해요',
      activityScoreText: '데이터가 부족해요',
    );
  }

  records.sort((a, b) => a.startTime.compareTo(b.startTime));

  // 평균 활동 시간
  final durations = <Duration>[];
  for (final r in records) {
    final dur = r.endTime.difference(r.startTime);
    if (dur.inSeconds > 0) durations.add(dur);
  }
  final total = durations.fold<Duration>(Duration.zero, (a, b) => a + b);
  final avgDur = total ~/ (durations.isEmpty ? 1 : durations.length);
  final avgActivityTimeText =
      '평균 ${avgDur.inHours}시간 ${avgDur.inMinutes % 60}분 활동했어요!';

  // ---- 기존 "평균 휴식 주기" 계산 로직을 아래로 교체 ----

// 휴식으로 인정할 범위(필요 시 조정)
  const _minRest = Duration(minutes: 5);   // 너무 짧은 간격(연속 기록) 제외
  const _maxRest = Duration(hours: 3);     // 하루를 건너뛰는 긴 공백 제외
  const _sameDayOnly = true;               // 날짜가 바뀌면 휴식으로 보지 않음

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  String _fmtAvgRestMinutesRobust(List<ActivityRecord> records) {
    if (records.length < 2) return '평균 0분 쉬었어요';

    // 시간순 정렬 보장
    records.sort((a, b) => a.startTime.compareTo(b.startTime));

    final gapsMin = <int>[];

    for (int i = 1; i < records.length; i++) {
      final prevEnd = records[i - 1].endTime.toUtc();
      final curStart = records[i].startTime.toUtc();

      // 시간 역전/동일시각 방어
      if (!curStart.isAfter(prevEnd)) continue;

      // (옵션) 같은 날 사이의 갭만 휴식으로 인정
      if (_sameDayOnly && !_isSameLocalDay(prevEnd, curStart)) continue;

      final gap = curStart.difference(prevEnd);

      // 너무 짧거나(연속 기록) 너무 긴(밤새/다음날) 갭은 제외
      if (gap < _minRest || gap > _maxRest) continue;

      gapsMin.add(gap.inMinutes);
    }

    if (gapsMin.isEmpty) return '평균 0분마다 쉬었어요';

    // 평균 대신 중앙값(이상치에 강함)
    gapsMin.sort();
    int medianMin;
    final n = gapsMin.length;
    if (n.isOdd) {
      medianMin = gapsMin[n ~/ 2];
    } else {
      medianMin = ((gapsMin[n ~/ 2 - 1] + gapsMin[n ~/ 2]) / 2).round();
    }

    return '평균 ${medianMin}분마다 쉬었어요!';
  }


  // 하이라이트 시간대
  final perHourMeters = List<double>.filled(24, 0.0);
  for (final r in records) {
    perHourMeters[r.startTime.hour] += r.distanceMeters;
  }
  int bestHour = 0;
  double bestMeters = -1;
  for (int h = 0; h < 24; h++) {
    final sum = perHourMeters[h] + perHourMeters[(h + 1) % 24];
    if (sum > bestMeters) {
      bestMeters = sum;
      bestHour = h;
    }
  }
  String _fmtHour(int h) {
    final isAm = h < 12;
    int h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '${isAm ? '오전' : '오후'} $h12시';
  }
  final highlightTimeText =
  bestMeters > 0 ? '${_fmtHour(bestHour)}~${_fmtHour((bestHour + 2) % 24)}에 가장 활발했어요!' : '데이터가 부족해요';

  // 활동 변화 추이
  final byDay = <DateTime, double>{};
  for (final r in records) {
    final d = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
    byDay.update(d, (v) => v + r.distanceMeters, ifAbsent: () => r.distanceMeters);
  }
  String trendText = '데이터가 부족해요';
  if (byDay.length >= 2) {
    final days = byDay.keys.toList()..sort();
    final last = byDay[days.last]!;
    final prev = byDay[days[days.length - 2]]!;
    if (prev > 0) {
      final diff = (last - prev) / prev;
      trendText = '전날보다 활동량이 ${(diff.abs()).toPercent()} ${diff >= 0 ? '증가' : '감소'}했어요!';
    }
  }

  // 최신 세션 점수
  final last = records.last;
  final res = ActivityScorer.computeFromRecord(
    distanceMeters: last.distanceMeters,
    startTime: last.startTime,
    endTime: last.endTime,
    catDob: catDob,
  );
  final activityScoreText = '활동량 ${res.score.round()}점! ${res.level}이에요!';

  return AnalyzeSummary(
    avgActivityTimeText: avgActivityTimeText,
    avgRestIntervalText: _fmtAvgRestMinutesRobust(List<ActivityRecord>.from(records)),
    highlightTimeText: highlightTimeText,
    trendText: trendText,
    activityScoreText: activityScoreText,
  );
}

// =================== UI ===================
class AiAnalyzePage extends StatefulWidget {
  const AiAnalyzePage({super.key});

  @override
  State<AiAnalyzePage> createState() => _AiAnalyzePageState();
}

class _AiAnalyzePageState extends State<AiAnalyzePage> {
  bool _loading = true;
  String _rangeText = '';
  AnalyzeSummary? _summary;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 8));
    final end = now;

    // TODO: 실제 고양이 DOB로 교체
    final catDob = DateTime(2016, 3, 15);

    final records = await ActivityApi.fetchRange(start: start, end: end);
    final summary = buildAnalyzeSummary(records: records, catDob: catDob);

    setState(() {
      _summary = summary;
      _rangeText = '${start.month}월 ${start.day}일부터 ${end.month}월 ${end.day}일까지의 분석';
      _loading = false;
    });
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
            'lib/assets/AI.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            'AI 분석 요약',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            _rangeText,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildInfoBlock(title: '총 활동 시간 (단위 : 일)', data: _summary?.avgActivityTimeText ?? '—'),
          _buildInfoBlock(title: '평균 휴식 주기', data: _summary?.avgRestIntervalText ?? '—'),
          _buildInfoBlock(title: '주요 활동 시간대', data: _summary?.highlightTimeText ?? '—'),
          _buildInfoBlock(title: '활동 변화 추이', data: _summary?.trendText ?? '—'),
          _buildInfoBlock(title: '활동량 점수', data: _summary?.activityScoreText ?? '—'),
        ],
      ),
    ),
    );
  }

  Widget _buildInfoBlock({required String title, required String data}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(data, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
