import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}
void _log(String msg) => debugPrint('[HomePage] $msg');

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

class _HomePageState extends State<HomePage> {
  String _catName = "로딩 중...";
  String _catAge = "로딩 중...";
  String _catWeight = "로딩 중...";
  File? _catImageFileToShow;
  List<BarChartGroupData> _dailyActivityBars = [];
  double _maxDailyActivity = 100;
  bool _isActivityLoading = true;
  List<BarChartGroupData> _dailyFeedingBars = [];
  double _maxDailyFeeding = 100;
  bool _isFeedingLoading = true;
  List<String> _feedingDateLabels = [];
  String? _localCatImagePath; // ✅ 로컬 저장된 프로필 이미지 경로


  late Future<void> _loadCatDataFuture;

  @override
  void initState() {
    super.initState();
    _loadLocalCatImage();
    _loadCatDataFuture = _loadCatData();
    _loadDailyActivityData();
    _loadDailyFeedingData();
  }


  Future<void> _loadLocalCatImage() async {
    final prefs = await SharedPreferences.getInstance();
    final p = prefs.getString('cat_image_path');
    if (p != null && File(p).existsSync()) {
      setState(() => _localCatImagePath = p);
      debugPrint('🐱 로컬 이미지 로드: $p');
    } else {
      debugPrint('⚠️ 로컬 이미지 없음');
    }
  }


  Future<void> _loadCatData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) throw Exception('저장된 사용자 ID 없음');

      final url = Uri.parse('http://192.168.100.130:3000/api/cats/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("서버 응답 데이터: $data");

        if (data is List && data.isNotEmpty) {
          final cat = data[0];

          String name = cat['name'] ?? '정보 없음';
          double? profileWeight = (cat['current_weight'] is num)
              ? (cat['current_weight'] as num).toDouble()
              : null;

// (선택) 감지 ID가 있다면 같이 보냄 — 없으면 주석 유지/삭제해도 됩니다.
          final String? detectionId =
          (cat['last_detection_id'] ?? cat['detection_id'])?.toString();

// ✅ AiFeedSettingPage와 같은 함수 호출
          final double? latestWeight = await fetchLatestWeight(
            // detectionId: detectionId ?? "image_0015",
          );

// 로컬 캐시(마지막 표시값)도 백업으로 사용
          final prefs = await SharedPreferences.getInstance();
          final double? cachedWeight = prefs.getDouble('_catWeight');

// 우선순위: 최신 체중 → 프로필 체중 → 로컬 캐시
          final double? weightToUse = latestWeight ?? profileWeight ?? cachedWeight;

// 화면 표시는 소문자 kg로 통일
          final String weightStr = (weightToUse != null)
              ? '${weightToUse.toStringAsFixed(1)} kg'
              : '몸무게 정보 없음';

          String age = "나이 정보 없음";
          if (cat['birth_date'] != null) {
            DateTime birthDate = DateTime.parse(cat['birth_date']);
            age = _calculateAge(birthDate);
          }

          File? imageFile;
          String? imagePath = cat['image_path'];
          if (imagePath != null) {
            final file = File(imagePath);
            if (await file.exists()) { // 파일 존재 여부 확인
              imageFile = file;
            }
          }

          if (mounted) {
            setState(() {
              _catName = name;
              _catWeight = weightStr;
              _catAge = age;
              _catImageFileToShow = imageFile;
            });
            if (mounted) {
              setState(() {
                _catWeight = weightStr;
              });
              if (weightToUse != null) {
                await prefs.setDouble('_catWeight', weightToUse); // 캐시 갱신
              }
            }
          }
        } else {
          throw Exception("고양이 정보 없음");
        }
      } else {
        throw Exception("서버 응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("고양이 정보 로드 에러: $e");
      if (mounted) {
        setState(() {
          _catName = "고양이";
          _catWeight = "2.5";
          _catAge = "2살";
          _catImageFileToShow = null;
        });
      }
    }
  }

  Future<void> _loadDailyActivityData() async {
    if (!mounted) return;
    setState(() {
      _isActivityLoading = true;
    });

    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> dummyActivityData = [
        {'start_time': now.subtract(Duration(days: 7)).toIso8601String(), 'distance': 350.0},
        {'start_time': now.subtract(Duration(days: 6)).toIso8601String(), 'distance': 350.0},
        {'start_time': now.subtract(Duration(days: 5)).toIso8601String(), 'distance': 380.0},
        {'start_time': now.subtract(Duration(days: 4)).toIso8601String(), 'distance': 390.0},
        {'start_time': now.subtract(Duration(days: 3)).toIso8601String(), 'distance': 350.0},
        {'start_time': now.subtract(Duration(days: 2)).toIso8601String(), 'distance': 280.0},
        {'start_time': now.subtract(Duration(days: 1)).toIso8601String(), 'distance': 410.0},
        {'start_time': now.toIso8601String(), 'distance': 500.0},
      ];

      // ✅ 2. 날짜별 distance 합산
      Map<String, double> activityMap = {};
      for (var item in dummyActivityData) {
        final start = DateTime.parse(item['start_time']);
        final dateStr = DateFormat('MM.dd').format(start);
        final distance = (item['distance'] is num) ? item['distance'].toDouble() : 0.0;
        activityMap.update(dateStr, (value) => value + distance, ifAbsent: () => distance);
      }

      final sortedKeys = activityMap.keys.toList()..sort();
      final recentKeys = sortedKeys.reversed.take(7).toList().reversed.toList();

      // ✅ 3. BarChart 데이터로 변환
      _dailyActivityBars = recentKeys.asMap().entries.map((entry) {
        final index = entry.key;
        final date = entry.value;
        final level = activityMap[date]!;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: level,
              color: Colors.orangeAccent,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList();

      // ✅ 4. 상태 업데이트
      if (mounted) {
        setState(() {
          _maxDailyActivity = _dailyActivityBars.isNotEmpty
              ? _dailyActivityBars.map((e) => e.barRods[0].toY).reduce(max) * 1.2
              : 100;
          _isActivityLoading = false;
        });
      }
    } catch (e) {
      print("더미 활동량 처리 중 에러 발생: $e");
      if (mounted) {
        setState(() {
          _isActivityLoading = false;
        });
      }
    }
  }

  Future<void> _loadDailyFeedingData() async {
    if (!mounted) return;
    setState(() {
      _isFeedingLoading = true;
    });

    final now = DateTime.now();
    final List<Map<String, dynamic>> dummyData = [
      // 날짜별로 여러 개의 데이터가 있어도 합산되는지 테스트하기 위해 일부 날짜는 2개씩 넣었어.
      {'time': now.subtract(const Duration(days: 5)).toIso8601String(), 'amount': 24.0},
      {'time': now.subtract(const Duration(days: 4)).toIso8601String(), 'amount': 24.0},
      {'time': now.subtract(const Duration(days: 3)).toIso8601String(), 'amount': 24.0},
      {'time': now.subtract(const Duration(days: 3)).toIso8601String(), 'amount': 12.0}, // 3일 전 추가 데이터
      {'time': now.subtract(const Duration(days: 2)).toIso8601String(), 'amount': 18.0},
      {'time': now.subtract(const Duration(days: 1)).toIso8601String(), 'amount': 12.0},
      {'time': now.subtract(const Duration(days: 1)).toIso8601String(), 'amount': 18.0}, // 어제 추가 데이터
      {'time': now.subtract(const Duration(hours: 3)).toIso8601String(), 'amount': 24.0}, // 오늘 데이터
    ];

    // 2. 더미 데이터를 사용해 차트 그리는 로직 (기존 로직과 동일)
    try {
      // 실제 서버에서 받아온 데이터라고 가정하고 'data' 변수에 할당
      final List<dynamic> data = dummyData;

      print('--- home_page.dart에서 사용하는 더미 급식량 데이터 ---');
      print(data);
      print('------------------------------------------------');

      Map<String, double> feedingMap = {};
      for (var item in data) {
        final date = DateTime.parse(item['time'] ?? DateTime.now().toIso8601String());
        final dateStr = DateFormat('MM.dd').format(date);
        final amount = (item['amount'] is num) ? item['amount'].toDouble() : 0.0;
        feedingMap.update(dateStr, (value) => value + amount, ifAbsent: () => amount);
      }

      final sortedKeys = feedingMap.keys.toList()..sort();

      _feedingDateLabels = sortedKeys.reversed.take(6).toList().reversed.toList();

      _dailyFeedingBars = _feedingDateLabels.asMap().entries.map((entry) {
        final index = entry.key;
        final date = entry.value;
        final amount = feedingMap[date]!;
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: amount,
              color: Colors.white,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }).toList();

      if (mounted) {
        setState(() {
          _maxDailyFeeding = _dailyFeedingBars.isNotEmpty
              ? _dailyFeedingBars.map((e) => e.barRods[0].toY).reduce(max) * 1.2
              : 100;
          _isFeedingLoading = false;
        });
      }
    } catch (e) {
      print("더미 데이터 처리 중 에러 발생: $e");
      if (mounted) {
        setState(() {
          _isFeedingLoading = false;
        });
      }
    }


    try {
      final response = await http.get(Uri.parse('http://192.168.100.130:3000/api/feeds/test_stream_1'));

      print("서버 응답 상태 코드: ${response.statusCode}");
      print("서버 응답 본문(raw): ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        print('--- home_page.dart에서 받아온 원본 급식량 데이터 ---');
        print(data);
        print('------------------------------------------------');

        print(" 파싱된 급식 데이터 목록:");
        for (var item in data) {
          print("➡️ 급식 시간: ${item['time']}, 급식량: ${item['amount']}");
        }

        Map<String, double> feedingMap = {};
        for (var item in data) {
          final date = DateTime.parse(item['time'] ?? DateTime.now().toIso8601String());
          final dateStr = DateFormat('MM.dd').format(date);
          final amount = (item['amount'] is num) ? item['amount'].toDouble() : 0.0; // 타입 검증
          feedingMap.update(dateStr, (value) => value + amount, ifAbsent: () => amount);
        }

        final sortedKeys = feedingMap.keys.toList()..sort();
        _feedingDateLabels = sortedKeys.reversed.take(6).toList().reversed.toList();

        _dailyFeedingBars = _feedingDateLabels.asMap().entries.map((entry) {
          final index = entry.key;
          final date = entry.value;
          final amount = feedingMap[date]!;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: Colors.greenAccent,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _maxDailyFeeding = _dailyFeedingBars.isNotEmpty
                ? _dailyFeedingBars.map((e) => e.barRods[0].toY).reduce(max) * 1.2
                : 100;
            _isFeedingLoading = false;
          });
        }
      } else {
        print("❌ 급식량 응답 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("급식량 불러오기 중 에러 발생: $e");
    }

    if (mounted) {
      setState(() {
        _isFeedingLoading = false;
      });
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

  Widget _buildGraphSection({
    required String title,
    required VoidCallback onTap, // 오타 수정: Void한 제거

  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), //급식량 폰트 사이즈 조절
        SizedBox(height: 15),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Color(0xffeee9ff),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: title == '일일 활동량'
                  ? (_isActivityLoading
                  ? Center(child: CircularProgressIndicator())
                  : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxDailyActivity,
                  barGroups: _dailyActivityBars,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 300,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 && _maxDailyActivity > 0) return Container();
                          if (value % 300 != 0) return Container();
                          return Text(value.toInt().toString(), style: TextStyle(fontSize: 10), textAlign: TextAlign.left);
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < _dailyActivityBars.length) {
                            return Text(
                              DateFormat('MM.dd').format(
                                DateTime.now().subtract(Duration(days: _dailyActivityBars.length - 1 - index)),
                              ),
                              style: TextStyle(fontSize: 10),
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 300,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.white, strokeWidth: 0.5), // 오타 수정
                  ),
                ),
              ))
                  : (_isFeedingLoading
                  ? Center(child: CircularProgressIndicator())
                  : (_dailyFeedingBars.isEmpty
                  ? Center(child: Text("데이터가 없습니다"))
                  : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxDailyFeeding,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 15,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: TextStyle(fontSize: 10), textAlign: TextAlign.left);
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < _feedingDateLabels.length) {
                            return Text(_feedingDateLabels[index], style: TextStyle(fontSize: 10));
                          }
                          return SizedBox.shrink();
                        },
                      ),
                    ),
                    // 위쪽 라벨 숨기기
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    // 오른쪽 라벨 숨기기
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true, // 그리드 선을 표시
                    drawVerticalLine: false, // 세로선은 끄기
                    horizontalInterval: 15, // 1단위로 가로선을 그림
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.black, // 투명도를 준 회색 선
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  barGroups: _dailyFeedingBars.map((group) { // 이 부분만 남겨두세요!
                    return BarChartGroupData(
                      x: group.x,
                      barRods: group.barRods.map((rod) {
                        return BarChartRodData(
                          toY: rod.toY,
                          color: Color(0xffab94ee), // 여기에 원하는 색상으로 변경!
                          width: 20,
                          borderRadius: BorderRadius.circular(5),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ))),

            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatInfoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[300],
          backgroundImage: (_localCatImagePath != null && File(_localCatImagePath!).existsSync())
              ? FileImage(File(_localCatImagePath!))                            // ✅ 로컬 파일 우선
              : (_catImageFileToShow != null ? FileImage(_catImageFileToShow!) : null), // (기존 fallback)
          child: (_localCatImagePath == null || !File(_localCatImagePath!).existsSync())
              ? (_catImageFileToShow == null ? Icon(Icons.pets, size: 60, color: Colors.white) : null)
              : null,
        ),
        SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 10),
            Text('$_catName', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 3),
            Text('$_catAge', style: TextStyle(fontSize: 16)),
            SizedBox(height: 3),
            Text('$_catWeight', style: TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyBarChart() {
    if (_dailyActivityBars.isEmpty) {
      return Center(child: Text('데이터가 없습니다.'));
    }
    return BarChart(
      BarChartData(
        backgroundColor: Colors.white,
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxDailyActivity,
        minY: 0,
        barGroups:  _dailyActivityBars.map((group) {
          return BarChartGroupData(
            x: group.x,
            barRods: group.barRods.map((rod) {
              return BarChartRodData(
                toY: rod.toY,
                color: Color(0xff5f33e1), // 여기를 원하는 색상으로 변경하면 돼!
                width: 20,
                borderRadius: BorderRadius.circular(5),
              );
            }).toList(),
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                String text = '';
                if (index >= 0 && index < _dailyActivityBars.length) {
                  text = DateFormat('MM.dd').format(
                    DateTime.now().subtract(Duration(days: _dailyActivityBars.length - 1 - index)),
                  );
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 100,
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
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300]!, strokeWidth: 0.5),
        ),
      ),
    );
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('건강하냥 ', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),),
            Image.asset(
              'lib/assets/cat_icon.png',
              width: 28, // 이미지 너비 조절
              height: 28, // 이미지 높이 조절
            ),
          ],
        ),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: '메뉴 열기',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              print('로그아웃: 저장된 고양이 정보 삭제 완료');
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      drawer: Container(
    decoration: const BoxDecoration(
    image: DecorationImage(
    image: AssetImage('lib/assets/bg1.png'),
    fit: BoxFit.cover,
    ),
    ),
    child: Drawer(
        backgroundColor: Colors.transparent,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                image: DecorationImage(
                    image:  AssetImage('lib/assets/bg1.png'),
                  fit: BoxFit.cover,
                )
              ),
              child: Text('메뉴', style: TextStyle(color: Colors.black, fontSize: 24)),
            ),
            ListTile(
              leading: Image.asset(
                'lib/assets/weight_icon.png',
                width: 24, // 이미지 너비 조절
                height: 24, // 이미지 높이 조절
              ),
              title: Text('체중변화'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/changeweight');
              },
            ),
            ListTile(
              leading: Image.asset(
                'lib/assets/hairball_icon.png',
                width: 24, // 이미지 너비 조절
                height: 24, // 이미지 높이 조절
              ),
              title: Text('활동량 변화'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/changemove');
              },
            ),
            ListTile(
              leading: Image.asset(
                'lib/assets/food_icon.png',
                width: 24, // 이미지 너비 조절
                height: 24, // 이미지 높이 조절
              ),
              title: Text('급식 설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/feedsetting');
              },
            ),
            // ListTile(
            //   leading: Image.asset(
            //     'lib/assets/food_icon.png',
            //     width: 24, // 이미지 너비 조절
            //     height: 24, // 이미지 높이 조절
            //   ),
            //   title: Text('급식 이력'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.pushNamed(context, '/feedrecord');
            //   },
            // ),
            ListTile(
              leading: Image.asset(
                'lib/assets/AI.png',
                width: 26, // 이미지 너비 조절
                height: 26, // 이미지 높이 조절
              ),
              title: Text('AI 분석 요약'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/aianalyze');
              },
            ),
            ListTile(
              leading: Image.asset(
                'lib/assets/set_icon.png',
                width: 24, // 이미지 너비 조절
                height: 24, // 이미지 높이 조절
              ),
              title: Text('설정'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadLocalCatImage(),
            _loadCatData(),
            _loadDailyActivityData(),
            _loadDailyFeedingData(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            FutureBuilder<void>(
              future: _loadCatDataFuture,
              builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return Center(child: Text("데이터 로드 중 에러 발생: ${snapshot.error} 😿"));
                  }
                  return _buildCatInfoSection();
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
            SizedBox(height: 26),
            _buildTitledChartCard(
              title: '일일 활동량',
              rightLabel: '',
              chart: _buildDailyBarChart(),
              onTap: () { Navigator.pushNamed(context, '/changemove'); },
              height: 200,
              bgColor: Colors.white,
              leading: Image.asset(    // ✅ 추가됨
                'lib/assets/hairball_icon.png',
                width: 24,
                height: 24,
              ),
            ),
            SizedBox(height: 35),
            _buildTitledChartCard(
              title: '급식량',
              chart: _buildFeedingBarChart(),
              onTap: () { Navigator.pushNamed(context, '/feedrecord'); },
              height: 200,
              titleFontSize: 20,
              bgColor: const Color(0xffffffff),               // 배경색 화이트로 변경
              border: Border.all(color: Colors.white, width: 1),
              leading: Image.asset(    // ✅ 추가됨
                'lib/assets/food_icon.png',
                width: 24,
                height: 24,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ],
        ),
      ),
    ),

    );
  }

  Widget _buildChartSection({required String title, required String yAxisLabel, required Widget chartWidget, VoidCallback? onTap,}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              yAxisLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 200,
            // padding: const EdgeInsets.only(top: 10, right: 10), // 기존 _buildDailyActivityBarChart 안에 있었던 padding은 차트 안에 포함되므로 여기서는 제거
            decoration: BoxDecoration(
              color: Colors.white, // 배경색을 여기서 지정
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, left: 10), // 필요에 따라 조정
              child: chartWidget,
            ),
          ),
        ),
      ],
    );
  }


//없애도 된다고 하는데 없애면 자꾸 화면이 안나옴
// ChartCard 빌더 함수
  Widget _buildTitledChartCard({
    required String title,
    required Widget chart,
    VoidCallback? onTap,
    String? rightLabel,                  // 오른쪽 작은 라벨(필요 없으면 null)
    double titleFontSize = 20,
    double height = 200,
    Color bgColor = Colors.white,
    EdgeInsets contentPadding = const EdgeInsets.only(top: 10, right: 10, left: 10),
    List<BoxShadow>? boxShadow,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
    BoxBorder? border,                   // 필요 시 흰 테두리 등
    Widget? leading,                     // ✅ 아이콘/이미지 추가 가능
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row( // ← 왼쪽 영역: leading + title
              children: [
                if (leading != null) ...[
                  leading,
                  const SizedBox(width: 6), // 아이콘과 글자 간격
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (rightLabel != null)
              Text(
                rightLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: borderRadius,
              boxShadow: boxShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
              border: border,
            ),
            child: Padding(
              padding: contentPadding,
              child: chart,
            ),
          ),
        ),
      ],
    );
  }

// 급식량 바차트 빌더 (클래스 상태값 사용)
  Widget _buildFeedingBarChart() {
    if (_isFeedingLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dailyFeedingBars.isEmpty) {
      return const Center(child: Text("데이터가 없습니다"));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxDailyFeeding,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 15,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.left,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < _feedingDateLabels.length) {
                  return Text(
                    _feedingDateLabels[index],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 15,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.black, strokeWidth: 0.5);
          },
        ),
        barGroups: _dailyFeedingBars.map((group) {
          return BarChartGroupData(
            x: group.x,
            barRods: group.barRods.map((rod) {
              return BarChartRodData(
                toY: rod.toY,
                color: const Color(0xffab94ee), // 급식량 바 색상
                width: 20,
                borderRadius: BorderRadius.circular(5),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }





}