import 'package:flutter/material.dart';

class AppSetting extends StatefulWidget {
  @override
  _AppSettingState createState() => _AppSettingState();
}

class _AppSettingState extends State<AppSetting> {
  bool _isFeedingAlarmOn = true;
  bool _isFoodShortageAlarmOn = true;
  bool _isHealthAnalysisAlarmOn = true;

  // 원하는 색상 정의
  final Color _activeColor = Color(0xff5f33e1); // 노란색

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
            'lib/assets/set_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '어플리케이션 설정',
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
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Text(
              '알림 On/Off',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
          ),

          // 스위치 커스텀 함수 사용
          _buildCustomSwitchTile(
            title: '급식 시간 알림',
            value: _isFeedingAlarmOn,
            onChanged: (value) {
              setState(() {
                _isFeedingAlarmOn = value;
              });
              print('급식 시간 알림: $value');
            },
          ),

          _buildCustomSwitchTile(
            title: '사료 부족 알림',
            value: _isFoodShortageAlarmOn,
            onChanged: (value) {
              setState(() {
                _isFoodShortageAlarmOn = value;
              });
              print('사료 부족 알림: $value');
            },
          ),

          _buildCustomSwitchTile(
            title: '건강 분석 결과 알림',
            value: _isHealthAnalysisAlarmOn,
            onChanged: (value) {
              setState(() {
                _isHealthAnalysisAlarmOn = value;
              });
              print('건강 분석 결과 알림: $value');
            },
          ),

          Divider(height: 30, thickness: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/notification_history');
                print('알림 이력 버튼 클릭됨');
              },
              child: Text(
                '알림 이력',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff5f33e1),
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // 공통 스타일 스위치 생성 함수
  Widget _buildCustomSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) return _activeColor;
            return Colors.grey;
          }),
          trackColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) return _activeColor.withOpacity(0.5);
            return Colors.black12;
          }),
        ),
      ),
      child: SwitchListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
