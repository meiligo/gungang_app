// lib/change_move_page.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// --- Data Models ---
// Represents activity level for a specific hour slot (e.g., 8 for 8:00-9:00 or 8:00-12:00 depending on server)
class HourlyActivity {
  final int hourSlot; // Represents the starting hour (e.g., 0, 4, 8, 12, 16, 20)
  final double activityLevel;
  HourlyActivity({required this.hourSlot, required this.activityLevel});
}


// Represents total activity level for a specific day
class DailyActivity {
  final DateTime date;
  final double activityLevel;
  DailyActivity({required this.date, required this.activityLevel});
}
// --------------------

class ChangeMovePage extends StatefulWidget {
  @override
  _ChangeMovePageState createState() => _ChangeMovePageState();
}

class _ChangeMovePageState extends State<ChangeMovePage> {
  // --- State Variables ---
  List<HourlyActivity> _hourlyActivity = [];
  List<DailyActivity> _dailyActivity = [];
  bool _isLoading = true;
  double _maxHourlyActivity = 0;
  double _maxDailyActivity = 0;
  // ----------------------

  @override
  void initState() {
    super.initState();
    _fetchActivityData();
  }

  // --- Fetch Data (Placeholder) ---
  Future<void> _fetchActivityData() async {
    setState(() => _isLoading = true);
    try {
      final url = 'http://192.168.100.130:3000/api/activities/catTest';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final List<dynamic> raw = jsonDecode(res.body);

      print(raw);
      // ---------- 시간별(4시간 슬롯) 집계 ----------
      // 0~3→0, 4~7→4, 8~11→8, 12~15→12, 16~19→16, 20~23→20
      final Map<int, double> hourlyMap = {0:0, 4:0, 8:0, 12:0, 16:0, 20:0};

      for (final e in raw) {
        final start = DateTime.parse(e['start_time']).toLocal();
        final dist  = (e['distance'] as num?)?.toDouble() ?? 0.0;

        final slot4h = (start.hour ~/ 4) * 4; // 0,4,8,12,16,20
        hourlyMap[slot4h] = (hourlyMap[slot4h] ?? 0.0) + dist;
      }

      final hourlyList = <HourlyActivity>[
        for (final h in [0,4,8,12,16,20])
          HourlyActivity(hourSlot: h, activityLevel: hourlyMap[h] ?? 0.0),
      ];

      // ---------- 일별 집계 ----------
      final Map<String, double> dailyMap = {};
      for (final e in raw) {
        final start = DateTime.parse(e['start_time']).toLocal();
        final key = DateFormat('yyyy-MM-dd').format(start); // 로컬 날짜 기준
        final dist = (e['distance'] as num?)?.toDouble() ?? 0.0;
        dailyMap[key] = (dailyMap[key] ?? 0.0) + dist;
      }

      var dailyList = dailyMap.entries
          .map((kv) => DailyActivity(date: DateTime.parse(kv.key), activityLevel: kv.value))
          .toList()
        ..sort((a,b) => a.date.compareTo(b.date));

      // (선택) 최근 7일만
      if (dailyList.length > 7) {
        dailyList = dailyList.sublist(dailyList.length - 7);
      }

      // ---------- y축 스케일 ----------
      double maxH = hourlyList.isEmpty ? 0.0
          : hourlyList.map((e) => e.activityLevel).reduce((a,b) => a>b?a:b);
      double maxD = dailyList.isEmpty ? 0.0
          : dailyList.map((e) => e.activityLevel).reduce((a,b) => a>b?a:b);

      maxH = maxH == 0 ? 90.0 : maxH * 1.2;
      maxD = maxD == 0 ? 900.0 : maxD * 1.2;

      if (!mounted) return;
      setState(() {
        _hourlyActivity = hourlyList;
        _dailyActivity = dailyList;
        _maxHourlyActivity = maxH;
        _maxDailyActivity = maxD;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hourlyActivity = [];
        _dailyActivity = [];
        _isLoading = false;
      });
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
    backgroundColor: Colors.transparent, // Scaffold의 배경을 투명하게 설정
    appBar: AppBar(
    backgroundColor: Colors.transparent, // AppBar 배경도 투명하게 설정
      title: Row(
        mainAxisSize: MainAxisSize.min, // Row의 크기를 내용물에 맞게 최소화
        children: [
          Image.asset(
            'lib/assets/hairball_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '활동량 변화',
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
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView( // Use SingleChildScrollView for potential overflow
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildChartSection(
              title: '시간별 활동량',
              yAxisLabel: '(m)', // Example unit
              chartWidget: _buildHourlyBarChart(),
            ),
            SizedBox(height: 40), // Spacing between charts
            _buildChartSection(
              title: '일일 활동량',
              yAxisLabel: '(m)', // Example unit
              chartWidget: _buildDailyBarChart(),
            ),
        SizedBox(height: 40,),
        ElevatedButton(
          onPressed: (){
            Navigator.pushNamed(context, '/moveanalyze');
          },
          child: Text("로그 확인", style: TextStyle(fontSize: 20, color: Colors.black)),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.white,// 버튼 내부 상하 여백
            shape: RoundedRectangleBorder(
              // 약간 둥근 모서리
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
          ],
        ),
      ),
    ),
    );
  }

  // --- Helper to build a chart section (Title + Chart) ---
  Widget _buildChartSection({required String title, required String yAxisLabel, required Widget chartWidget}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row( // Title and Y-axis label
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              yAxisLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: 200, // Fixed height for the chart area
          child: chartWidget,
        ),
      ],
    );
  }
  // ------------------------------------------------------

  // --- Build Hourly Bar Chart ---
  Widget _buildHourlyBarChart() {
    if (_hourlyActivity.isEmpty) {
      return Center(child: Text('데이터가 없습니다.'));
    }
    return BarChart(
      BarChartData(
        backgroundColor: Colors.white,
        alignment: BarChartAlignment.spaceEvenly,
        maxY: _maxHourlyActivity,
        minY: 0,
        barGroups: _hourlyActivity.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index, // Use index for x position
            barRods: [
              BarChartRodData(
                toY: data.activityLevel,
                color: Color(0xffab94ee), // Bar color
                width: 20, // Bar width
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles( // X-axis: Hours
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // Show every label
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                String text = '';
                if (index >= 0 && index < _hourlyActivity.length) {
                  // Display the starting hour of the slot
                  text = _hourlyActivity[index].hourSlot.toString();
                  // Show labels only at intervals matching the image (0, 4, 8...)
                  if (![0, 4, 8, 12, 16, 20].contains(_hourlyActivity[index].hourSlot)) {
                    text = ''; // Hide labels not in the list
                  }
                }
                // Adjust interval visually if needed - this just controls rendering
                // if (index % 1 != 0) { text = '';} // Example: show every other label if crowded

                return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(text, style: TextStyle(fontSize: 10)));
              },
            ),
          ),
          leftTitles: AxisTitles( // Y-axis: Activity Level
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 100, // Interval based on image (0, 30, 60, 90)
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10), textAlign: TextAlign.left);
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false), // Hide border
        gridData: FlGridData( // Configure grid lines
          show: true,
          drawVerticalLine: false, // Hide vertical grid
          horizontalInterval: 100, // Horizontal grid interval
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey, strokeWidth: 0.5),
        ),
      ),
    );
  }
  // -----------------------------

  // --- Build Daily Bar Chart ---
  Widget _buildDailyBarChart() {
    if (_dailyActivity.isEmpty) {
      return Center(child: Text('데이터가 없습니다.'));
    }
    return BarChart(
      BarChartData(
        backgroundColor: Colors.white,
        alignment: BarChartAlignment.spaceEvenly,
        maxY: _maxDailyActivity,
        minY: 0,
        barGroups: _dailyActivity.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data.activityLevel,
                color: Color(0xff5f33e1), // Bar color
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles( // X-axis: Dates
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                String text = '';
                if (index >= 0 && index < _dailyActivity.length) {
                  text = DateFormat('MM.dd').format(_dailyActivity[index].date);
                }
                return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(text, style: TextStyle(fontSize: 10)));
              },
            ),
          ),
          leftTitles: AxisTitles( // Y-axis: Activity Level
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 100, // Interval based on image (300, 600, 900)
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: TextStyle(fontSize: 10), textAlign: TextAlign.left);
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey, strokeWidth: 0.5),
        ),
      ),
    );
  }
// -----------------------------
}