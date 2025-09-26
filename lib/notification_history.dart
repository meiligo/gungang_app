import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String message;
  final DateTime timestamp;

  NotificationItem({required this.message, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };

  static NotificationItem fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class NotificationHistory extends StatefulWidget {
  @override
  _NotificationHistoryState createState() => _NotificationHistoryState();
}

class _NotificationHistoryState extends State<NotificationHistory> {
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _addTestNotification(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final newItem = NotificationItem(message: message, timestamp: now);
    final history = prefs.getStringList('notificationHistory') ?? [];

    history.insert(0, json.encode(newItem.toJson())); // 최신 알림 위에 추가
    await prefs.setStringList('notificationHistory', history);

    _loadNotifications(); // 다시 로드
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('notificationHistory') ?? [];

    setState(() {
      _notifications = raw
          .map((e) => NotificationItem.fromJson(json.decode(e) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 최신순 정렬
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('M월 d일', 'ko_KR').format(dt);
  }

  String _formatTime(DateTime dt) {
    return DateFormat('a hh:mm', 'ko_KR').format(dt);
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
            'lib/assets/set_icon.png', // 여기에 이미지 경로를 넣어줘
            width: 24, // 아이콘 크기 조절
            height: 24,
          ),
          const SizedBox(width: 8), // 아이콘과 텍스트 사이 간격
          const Text(
            '알림 이력',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),

        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.add_alert),
            onPressed: () {
              _addTestNotification('테스트 알림이 도착했습니다!');
            },
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(child: Text('알림 이력이 없습니다.', style: TextStyle(fontSize: 16)))
          : ListView.separated(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final item = _notifications[index];
          return ListTile(
            contentPadding:
            EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            title: Text(
              item.message,
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatDate(item.timestamp),
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
                SizedBox(height: 2),
                Text(_formatTime(item.timestamp),
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey[200],
          indent: 16,
          endIndent: 16,
        ),
      ),
    ),
    );
  }
}
