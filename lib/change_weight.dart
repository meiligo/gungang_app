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

    // TODO: 실제 서버 API 호출 로직으로 대체해야 함
    // 예시: http.get('/api/cat/weight-history'), 응답 파싱 등
    await Future.delayed(Duration(seconds: 1)); // 임시로 1초 딜레이

    // --- 가짜 데이터 생성 (이미지와 유사하게) ---
    final dummyData = [
      WeightData(timeLabel: '5주전', weight: 2.9),
      WeightData(timeLabel: '4주전', weight: 2.9),
      WeightData(timeLabel: '3주전', weight: 3.1),
      WeightData(timeLabel: '2주전', weight: 3.2), // 이미지 최고점
      WeightData(timeLabel: '1주전', weight: 3.1),
      WeightData(timeLabel: '현재', weight: 3.0),
    ];
    // ------------------------------------

    // 데이터 업데이트 및 로딩 종료
    setState(() {
      _weightHistory = dummyData;
      _isLoading = false;
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
    backgroundColor: Colors.transparent, // Scaffold의 배경을 투명하게 설정
    appBar: AppBar(
    backgroundColor: Colors.transparent, // AppBar 배경도 투명하게 설정
      title: Row(
        mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 최소화
        children: [
          Image.asset(
            'lib/assets/weight_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '체중 변화',
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 300,
                width: double.infinity,
                color: Colors.white,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _weightHistory.isEmpty
                    ? const Center(child: Text('체중 기록이 없습니다.'))
                    : _buildChart(),
              ),
              const SizedBox(height: 100),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _visibleCount,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 0.0),
                    child: SizedBox(
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/weightanalyze');
                        },
                        child: Text(
                          '로그 확인',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // if (_visibleCount < _allButtons.length)
              //   Padding(
              //     padding: const EdgeInsets.only(top: 4.0),
              //     child: SizedBox(
              //       height: 50,
              //       child: ElevatedButton(
              //         style: ElevatedButton.styleFrom(
              //           backgroundColor: Colors.grey[200],
              //           elevation: 0,
              //         ),
              //         onPressed: () {
              //           setState(() {
              //             _visibleCount = (_visibleCount + 5).clamp(0, _allButtons.length);
              //           });
              //         },
              //         child: const Text('더보기', style: TextStyle(color: Colors.black)),
              //       ),
              //     ),
              //   ),
            ],
          ),
        ),
      ),
    ),
    );
  }


  // --- LineChart 위젯 생성 함수 ---
  Widget _buildChart() {
    // Y축 최소/최대값 계산 (데이터 기반 + 약간의 여백)
    final weights = _weightHistory.map((data) => data.weight).toList();
    final minY = (weights.reduce(min) - 0.5).floorToDouble(); // 최소값보다 0.5 작게
    final maxY = (weights.reduce(max) + 0.5).ceilToDouble();  // 최대값보다 0.5 크게

    return LineChart(
      LineChartData(
        backgroundColor: Colors.white,
        // --- 축 타이틀 설정 ---
        titlesData: FlTitlesData(
          // 아래쪽 (X축) 타이틀
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36, // 타이틀 공간 확보
              interval: 1, // 모든 레이블 표시
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _weightHistory.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0, // 타이틀과 축 사이 간격
                    child: Text(
                      _weightHistory[index].timeLabel,
                      style: TextStyle(fontSize: 10), // 폰트 크기 조절
                    ),
                  );
                }
                return Text('');
              },
            ),
          ),
          // 왼쪽 (Y축) 타이틀
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40, // 타이틀 공간 확보
              interval: 0.5, // 0.5 단위로 표시
              getTitlesWidget: (value, meta) {
                // 맨 위와 맨 아래는 표시 안 함 (선택 사항)
                // if (value == meta.max || value == meta.min) {
                //   return Container();
                // }
                return Text(
                  value.toStringAsFixed(1), // 소수점 1자리까지
                  style: TextStyle(fontSize: 10),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          // 위쪽, 오른쪽 타이틀 숨기기
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),

        // --- 테두리 설정 ---
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1), // 연한 회색 테두리
        ),

        // --- 그리드 설정 ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true, // 세로선 표시
          horizontalInterval: 0.5, // 가로선 간격 (Y축 interval과 동일하게)
          verticalInterval: 1, // 세로선 간격 (X축 interval과 동일하게)
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey[200]!, strokeWidth: 1); // 연한 회색 가로선
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey[200]!, strokeWidth: 1); // 연한 회색 세로선
          },
        ),

        // --- 데이터 포인트 설정 ---
        lineBarsData: [
          LineChartBarData(
            // 데이터 점 리스트 (x: index, y: weight)
            spots: _weightHistory.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.weight);
            }).toList(),
            isCurved: true, // 부드러운 곡선
            color: Colors.blue, // 선 색상
            barWidth: 3, // 선 두께
            isStrokeCapRound: true, // 선 끝 모양 둥글게
            dotData: FlDotData(show: true), // 데이터 점 표시
            belowBarData: BarAreaData(show: false), // 선 아래 영역 채우기 안 함
          ),
        ],

        // --- 차트 전체 범위 설정 ---
        minX: 0, // X축 시작 (첫 번째 데이터 인덱스)
        maxX: (_weightHistory.length - 1).toDouble(), // X축 끝 (마지막 데이터 인덱스)
        minY: minY, // 계산된 Y축 최소값
        maxY: maxY, // 계산된 Y축 최대값
      ),
    );
  }
}