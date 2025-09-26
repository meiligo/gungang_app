// lib/weight_change_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // min/max 계산 위해 추가

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

  @override
  void initState() {
    super.initState();
    _fetchWeightData(); // 화면 시작 시 데이터 가져오기
  }

  // --- 서버에서 데이터 가져오는 함수 (Placeholder) ---
  Future<void> _fetchWeightData() async {
    setState(() {
      _isLoading = true; // 로딩 시작
    });

    await Future.delayed(const Duration(seconds: 1)); // 임시 딜레이

    final dummyData = [
      WeightData(timeLabel: '5주전', weight: 2.9),
      WeightData(timeLabel: '4주전', weight: 2.9),
      WeightData(timeLabel: '3주전', weight: 3.1),
      WeightData(timeLabel: '2주전', weight: 3.2), // 최고점
      WeightData(timeLabel: '1주전', weight: 3.1),
      WeightData(timeLabel: '현재', weight: 3.0),
    ];

    setState(() {
      _weightHistory = dummyData;
      _isLoading = false;
    });
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ 그래프 카드: 그림자 + 라운드 + 안쪽 살짝 패딩
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
                    // 바깥 패딩(프레임 여백): 내부 그래프와 카드 테두리 사이에 살짝 공간
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20.0, right: 20.0,bottom:10.0),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _weightHistory.isEmpty
                          ? const Center(child: Text('체중 기록이 없습니다.'))
                          : _buildChart(), // ← 실제 그래프
                    ),
                  ),
                ),

                const SizedBox(height: 100),

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
  // --- LineChart 위젯 생성 함수 ---
  Widget _buildChart() {
    // 데이터가 있다고 가정 (위에서 empty 체크)
    final weights = _weightHistory.map((d) => d.weight).toList();

    // 기본 여유(기존): 아래 0.5, 위 0.5
    final baseMinY = (weights.reduce(min) - 0.5).floorToDouble();
    final baseMaxY = (weights.reduce(max) + 0.5).ceilToDouble();

    // ✅ 그래프 내부 top/right 여백 (필요시 값만 조절하면 됨)
    const extraTopHeadroom = 0.5;   // 상단 여백 (kg)
    //const extraRightHeadroom = 0.5; // 우측 여백 (인덱스 단위)

    final minY = baseMinY;
    final maxY = baseMaxY + extraTopHeadroom;

    final lastIndex = _weightHistory.length - 1;
    final minX = 0.0;
    final maxX = lastIndex.toDouble() ;//+ extraRightHeadroom;

    return LineChart(
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
                // ✅ 정수 눈금에서만, 0..lastIndex 범위만 라벨 표시
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
              reservedSize: 40,
              interval: 0.5,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
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
          horizontalInterval: 0.5,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        ),

        // 데이터
        lineBarsData: [
          LineChartBarData(
            spots: _weightHistory.asMap().entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
                .toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],

        // ✅ 내부 여백 반영된 범위
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,

        clipData: const FlClipData.all(),
      ),
    );
  }

}
