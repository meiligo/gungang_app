// lib/weight_change_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:convert';                       // ★ 추가
import 'package:http/http.dart' as http;     // ★ 추가
import 'package:shared_preferences/shared_preferences.dart'; // ★ 추가

// 간단한 체중 데이터 모델 (서버 응답 구조에 맞게 수정 필요)
class WeightData {
  final String timeLabel; // X축 레이블 (예: "5주전", "현재")
  final double weight;    // Y축 값 (체중)
  WeightData({required this.timeLabel, required this.weight});
}

class ChangeWeightPage extends StatefulWidget {
  @override
  _ChangeWeightPageState createState() => _ChangeWeightPageState();
}

class _ChangeWeightPageState extends State<ChangeWeightPage> {
  List<WeightData> _weightHistory = []; // 서버에서 가져올 데이터 리스트
  bool _isLoading = true; // 로딩 상태 표시

  final List<String> _allButtons = List.generate(20, (index) => '로그확인 ${index + 1}');
  int _visibleCount = 1;

  // ★ 서버 접속 기본값
  final String _apiBase = 'http://192.168.100.130:3000/api/health'; // 엔드포인트 베이스
  final int _rangeWeeks = 6;                                        // 최근 n주
  final String _groupBy = 'week';                                   // week|day|raw

  // ========= 상위 여백 조절용 =========
  double topExtraSpacing = 0.0;
  double gapBetweenChartAndInfo = 30.0; // 그래프와 안내박스 사이 여백

  // ========= 스타일/옵션(원하는 대로 조절) =========
  final Color lineColor = const Color(0xFF5F33E1);
  final double lineWidth = 3.0;
  final double dotRadius = 3.5;
  final Color valueLabelColor = Colors.black;
  final double valueLabelFontSize = 12.0;
  final Color axisLabelColor = Colors.black87;
  final Color gray = Color(0xff4a4a4a);
  final Color lightGray = Color(0xffaaaaaa);
  final double axisLabelFontSize = 10.0;
  final double yInterval = 0.2;

  // 차트/라벨 페인터 좌표 보정용 패딩(차트/Painter 동일 사용)
  final double leftReservedSize = 44;
  final double chartTopPadding = 12;
  final double chartRightPadding = 16;
  final double chartBottomPadding = 22;

  // ========= 최고 체중 하이라이트 박스 옵션 =========
  final bool showMaxBox = true;
  final Color maxBoxStrokeColor = const Color(0xFF5F33E1);
  final double maxBoxStrokeWidth = 2.0;
  final Color maxBoxFillColor = const Color(0x1A5F33E1);
  final double maxBoxWidth = 60;
  final double maxBoxHeight = 28;
  final double maxBoxCorner = 8;
  final double maxBoxYOffset = 18;
  final bool showMaxBoxLabel = true;
  final String maxBoxLabelText = '최고';
  final TextStyle maxBoxLabelStyle = const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF5F33E1),
  );

  // ========= ✅ AI 체중 예측 안내 박스 옵션 =========
  final bool showAiInfoBox = true;
  final Color aiInfoBgColor = const Color(0xFFAB94EE);
  final Color aiInfoTextColor = Colors.white;
  double aiInfoFontSize = 12.0;
  final double aiInfoBorderRadius = 10.0;
  final EdgeInsets aiInfoPadding = const EdgeInsets.fromLTRB(12, 10, 12, 12);
  final FontWeight aiInfoTitleWeight = FontWeight.w700;
  final FontWeight aiInfoBodyWeight  = FontWeight.w400;
  final FontWeight aiInfoEmphWeight  = FontWeight.w700;

  @override
  void initState() {
    super.initState();
    _fetchWeightData(); // 화면 시작 시 데이터 가져오기
  }

  // --- 서버에서 데이터 가져오는 함수 (실동) ---
  Future<void> _fetchWeightData() async {                 // ★ 교체
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1) catId 우선 사용, 없으면 userId로 첫 고양이 조회해 catId 확보
      String? catId = prefs.getString('_catId');
      if (catId == null || catId.isEmpty) {
        final userId = prefs.getString('userId');
        if (userId == null) throw Exception('userId/catId 없음');

        final catRes = await http.get(
          Uri.parse('http://192.168.100.130:3000/api/cats/$userId'),
        );
        if (catRes.statusCode != 200) {
          throw Exception('고양이 조회 실패: ${catRes.statusCode}');
        }
        final cats = json.decode(catRes.body);
        if (cats is! List || cats.isEmpty) {
          throw Exception('등록된 고양이 없음');
        }
        final first = cats.first;
        catId = (first['_id'] ?? first['id'] ?? '').toString();
        if (catId.isEmpty) throw Exception('catId 파싱 실패');
        await prefs.setString('_catId', catId);
      }

      // 2) 시계열 체중 조회
      final uri = Uri.parse(
        '$_apiBase/cats/$catId/weights?rangeWeeks=$_rangeWeeks&groupBy=$_groupBy',
      );
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('체중 조회 실패: ${res.statusCode}');
      }

      final Map<String, dynamic> body = json.decode(res.body);
      final List pts = (body['points'] ?? []) as List;

      // 3) 시간 정렬 + 라벨 생성
      final now = DateTime.now();
      final raw = pts.map((p) {
        final t = DateTime.parse(p['t'] as String);
        final w = (p['w'] as num).toDouble();
        return {'t': t, 'w': w};
      }).toList()
        ..sort((a, b) => (a['t'] as DateTime).compareTo(b['t'] as DateTime));

      final history = raw.map((e) {
        final t = e['t'] as DateTime;
        final w = e['w'] as double;
        final diffDays = now.difference(t).inDays;
        final weeks = (diffDays / 7).floor();
        final label = weeks <= 0 ? '현재' : '${weeks}주전';
        return WeightData(timeLabel: label, weight: w);
      }).toList();

      setState(() {
        _weightHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchWeightData error: $e');
      setState(() {
        _weightHistory = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('lib/assets/bg1.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('lib/assets/weight_icon.png', width: 24, height: 24),
              const SizedBox(width: 8),
              const Text('체중 변화', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16 + topExtraSpacing, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ 그래프 카드
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0, right: 12.0, bottom: 8.0, left: 8.0),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _weightHistory.isEmpty
                          ? const Center(child: Text('체중 기록이 없습니다.'))
                          : _buildChart(),
                    ),
                  ),
                ),

                // const SizedBox(height: 12),                // 기존 고정
                SizedBox(height: gapBetweenChartAndInfo),     // ★ 여백 변수 적용

                // ✅ AI 체중 예측 안내 박스 (그래프와 로그 버튼 사이)
                if (showAiInfoBox) _buildAiInfoPanel(),

                const SizedBox(height: 16),

                // 리스트 버튼 (그림자 포함)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visibleCount,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: SizedBox(
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/weightanalyze');
                            },
                            child: const Text(
                              '로그 확인',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- LineChart 위젯 생성 함수 ---
  Widget _buildChart() {
    final lastIndex = _weightHistory.length - 1;
    final weights = _weightHistory.map((e) => e.weight).toList();

    // y범위(0.2 단위 스냅 + 약간 여유)
    final minW = weights.reduce(min);
    final maxW = weights.reduce(max);
    final minY = _floorTo(minW - 0.1, yInterval);
    final maxY = _ceilTo(maxW + 0.1, yInterval);

    final minX = 0.0;
    final maxX = lastIndex.toDouble();

    final spots = _weightHistory.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
        .toList();

    // 최고 체중 인덱스(여러 개면 가장 앞의 것)
    final int maxIdx = weights.indexOf(maxW);
    final FlSpot maxSpot = FlSpot(maxIdx.toDouble(), maxW);

    // 차트 본체
    final chart = LineChart(
      LineChartData(
        backgroundColor: Colors.white,

        // 축/타이틀
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final isIntegerTick = (value % 1 == 0);
                if (!isIntegerTick) return const SizedBox.shrink();
                final i = value.toInt();
                if (i < 0 || i > lastIndex) return const SizedBox.shrink();
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(
                    _weightHistory[i].timeLabel,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: leftReservedSize,
              interval: yInterval, // 0.2kg 간격
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: axisLabelFontSize, color: axisLabelColor),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),

        // 테두리
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),

        // 그리드
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yInterval, // 0.2kg
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        ),

        // 데이터
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: lineWidth,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: dotRadius,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: lineColor,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],

        // 범위
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,

        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false), // 툴팁X(항상 숫자 표기)
      ),
    );

    // 차트 위에 "kg", 점 위 수치, 최고 체중 박스를 얹기 위해 Stack 사용
    return Stack(
      children: [
        chart,

        // 그래프 상단 우측에 "kg" 단위 표시
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '(단위 : kg)',
              style: TextStyle(
                fontSize: 12,
                color: lightGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // 각 데이터 점 위에 체중 숫자 기록 (항상 표시)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ValueLabelPainter(
                spots: spots,
                labels: _weightHistory.map((e) => e.weight.toStringAsFixed(2)).toList(),
                minX: 0.0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                leftReservedSize: leftReservedSize,
                topPadding: chartTopPadding,
                rightPadding: chartRightPadding,
                bottomPadding: chartBottomPadding,
                textStyle: TextStyle(
                  color: valueLabelColor,
                  fontSize: valueLabelFontSize,
                  fontWeight: FontWeight.w600,
                ),
                labelGap: -18,
              ),
            ),
          ),
        ),

        // ✅ 최고 체중 박스
        if (showMaxBox)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MaxBoxPainter(
                  spot: maxSpot,
                  minX: 0.0,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  leftReservedSize: leftReservedSize,
                  topPadding: chartTopPadding,
                  rightPadding: chartRightPadding,
                  bottomPadding: chartBottomPadding,
                  boxWidth: maxBoxWidth,
                  boxHeight: maxBoxHeight,
                  boxCorner: maxBoxCorner,
                  strokeColor: maxBoxStrokeColor,
                  strokeWidth: maxBoxStrokeWidth,
                  fillColor: maxBoxFillColor,
                  yOffset: maxBoxYOffset,
                  showLabel: showMaxBoxLabel,
                  labelText: maxBoxLabelText,
                  labelStyle: maxBoxLabelStyle,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ✅ AI 체중 예측 안내 박스
  Widget _buildAiInfoPanel() {
    return Container(
      width: double.infinity,
      padding: aiInfoPadding,
      decoration: BoxDecoration(
        color: aiInfoBgColor,
        borderRadius: BorderRadius.circular(aiInfoBorderRadius),
      ),
      child: _buildAiInfoRichText(
        fontSize: aiInfoFontSize,
        titleWeight: aiInfoTitleWeight,
        bodyWeight: aiInfoBodyWeight,
        emphWeight: aiInfoEmphWeight,
        color: aiInfoTextColor,
      ),
    );
  }

  Widget _buildAiInfoRichText({
    required double fontSize,
    required FontWeight titleWeight,
    required FontWeight bodyWeight,
    required FontWeight emphWeight,
    required Color color,
  }) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, color: color, height: 1.35),
        children: [
          TextSpan(text: '• AI 체중 예측 안내\n', style: TextStyle(fontWeight: titleWeight)),
          const TextSpan(text: 'YOLO+CNN ',),
          TextSpan(text: '기반 예측값', style: TextStyle(fontWeight: emphWeight)),
          TextSpan(text: '입니다.\n', style: TextStyle(fontWeight: bodyWeight)),
          TextSpan(text: '자세·조명에 따라 오차가 있을 수 있으며,\n', style: TextStyle(fontWeight: bodyWeight)),
          TextSpan(text: '데이터가 쌓이면 ', style: TextStyle(fontWeight: bodyWeight)),
          TextSpan(text: '±0.1kg', style: TextStyle(fontWeight: emphWeight)),
          TextSpan(text: '까지 정밀해집니다.', style: TextStyle(fontWeight: bodyWeight)),
        ],
      ),
      textAlign: TextAlign.left,
    );
  }

  double _floorTo(double v, double step) => (v / step).floor() * step;
  double _ceilTo(double v, double step) => (v / step).ceil() * step;
}

// 점 위 숫자를 그려주는 커스텀 페인터
class _ValueLabelPainter extends CustomPainter {
  final List<FlSpot> spots;
  final List<String> labels;
  final double minX, maxX, minY, maxY;
  final double leftReservedSize, topPadding, rightPadding, bottomPadding;
  final TextStyle textStyle;
  final double labelGap;

  _ValueLabelPainter({
    required this.spots,
    required this.labels,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.leftReservedSize,
    required this.topPadding,
    required this.rightPadding,
    required this.bottomPadding,
    required this.textStyle,
    this.labelGap = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spots.isEmpty) return;

    final chartWidth = size.width - leftReservedSize - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    Offset toPx(FlSpot s) {
      final dx = leftReservedSize + ((s.x - minX) / (maxX - minX)) * chartWidth;
      final dy = topPadding + (1 - ((s.y - minY) / (maxY - minY))) * chartHeight;
      return Offset(dx, dy);
    }

    for (int i = 0; i < spots.length; i++) {
      final p = toPx(spots[i]);

      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelPos = Offset(p.dx - tp.width / 2, p.dy - tp.height - labelGap);
      tp.paint(canvas, labelPos);
    }
  }

  @override
  bool shouldRepaint(covariant _ValueLabelPainter old) {
    return old.spots != spots ||
        old.labels != labels ||
        old.minX != minX ||
        old.maxX != maxX ||
        old.minY != minY ||
        old.maxY != maxY ||
        old.leftReservedSize != leftReservedSize ||
        old.topPadding != topPadding ||
        old.rightPadding != rightPadding ||
        old.bottomPadding != bottomPadding ||
        old.textStyle != textStyle ||
        old.labelGap != labelGap;
  }
}

// 최고 체중 지점에 박스를 그려주는 커스텀 페인터
class _MaxBoxPainter extends CustomPainter {
  final FlSpot spot;
  final double minX, maxX, minY, maxY;
  final double leftReservedSize, topPadding, rightPadding, bottomPadding;

  final double boxWidth;
  final double boxHeight;
  final double boxCorner;
  final double strokeWidth;
  final Color strokeColor;
  final Color fillColor;
  final double yOffset;
  final bool showLabel;
  final String labelText;
  final TextStyle labelStyle;

  _MaxBoxPainter({
    required this.spot,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.leftReservedSize,
    required this.topPadding,
    required this.rightPadding,
    required this.bottomPadding,
    required this.boxWidth,
    required this.boxHeight,
    required this.boxCorner,
    required this.strokeColor,
    required this.strokeWidth,
    required this.fillColor,
    required this.yOffset,
    required this.showLabel,
    required this.labelText,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - leftReservedSize - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final dx = leftReservedSize + ((spot.x - minX) / (maxX - minX)) * chartWidth;
    final dy = topPadding + (1 - ((spot.y - minY) / (maxY - minY))) * chartHeight;

    Rect box = Rect.fromCenter(
      center: Offset(dx, dy - yOffset - 20),
      width: boxWidth,
      height: boxHeight,
    );

    final double leftBound = leftReservedSize + 2;
    final double rightBound = size.width - rightPadding - 2;
    final double topBound = topPadding + 2;
    final double bottomBound = size.height - bottomPadding - 2;

    if (box.left < leftBound) {
      box = box.shift(Offset(leftBound - box.left, 0));
    } else if (box.right > rightBound) {
      box = box.shift(Offset(rightBound - box.right, 0));
    }
    if (box.top < topBound) {
      box = box.shift(Offset(0, topBound - box.top));
    } else if (box.bottom > bottomBound) {
      box = box.shift(Offset(0, bottomBound - box.bottom));
    }

    final rrect = RRect.fromRectAndRadius(box, Radius.circular(boxCorner));

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawRRect(rrect, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor;
    canvas.drawRRect(rrect, strokePaint);

    if (showLabel && labelText.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: labelText, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: boxWidth - 8);
      final labelPos = Offset(
        box.center.dx - tp.width / 2,
        box.center.dy - tp.height / 2,
      );
      tp.paint(canvas, labelPos);
    }
  }

  @override
  bool shouldRepaint(covariant _MaxBoxPainter old) {
    return old.spot != spot ||
        old.minX != minX ||
        old.maxX != maxX ||
        old.minY != minY ||
        old.maxY != maxY ||
        old.leftReservedSize != leftReservedSize ||
        old.topPadding != topPadding ||
        old.rightPadding != rightPadding ||
        old.bottomPadding != bottomPadding ||
        old.boxWidth != boxWidth ||
        old.boxHeight != boxHeight ||
        old.boxCorner != boxCorner ||
        old.strokeColor != strokeColor ||
        old.strokeWidth != strokeWidth ||
        old.fillColor != fillColor ||
        old.yOffset != yOffset ||
        old.showLabel != showLabel ||
        old.labelText != labelText ||
        old.labelStyle != labelStyle;
  }
}
