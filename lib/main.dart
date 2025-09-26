import 'package:flutter/material.dart';
import 'package:flutter_application_1/cat_register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'change_weight.dart';
import 'change_move.dart';
import 'feed_setting.dart';
import 'feed_record.dart';
import 'AI_Analyze.dart';
import 'user_settings.dart';
import 'cat_info_edit_page.dart';
import 'app_setting.dart';
import 'signup.dart';
import 'AI_feeding.dart';
import 'self_feeding.dart';
import 'find_password.dart';
import 'notification_history.dart';
import 'move_analyze.dart';
import 'weight_analyze.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Future<Widget> _getInitialPage() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    bool isCatRegistered = prefs.getBool('isCatRegistered') ?? false;

    if (isLoggedIn) {
      return isCatRegistered ? HomePage() : LoginPage();
    } else {
      return LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '냥터링',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          } else {
            return Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
      routes: {
        '/weightanalyze': (context) => WeightAnalyze(),
        '/moveanalyze': (context) => MoveAnalyze(),
        '/login': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/signup': (context) => SignupPage(),
        '/catregister': (context) => CatRegisterPage(),
        '/settings': (context) => SettingsPage(),
        '/changeweight': (context) => ChangeWeightPage(),
        '/changemove': (context) => ChangeMovePage(),
        '/feedsetting': (context) => FeedSettingPage(),
        '/feedrecord': (context) => FeedRecordPage(),
        '/aianalyze': (context) => AiAnalyzePage(),
        '/usersetting': (context) => UserSettings(),
        '/catinfoedit': (context) => CatInfoEditPage(),
        '/appsetting': (context) => AppSetting(),
        '/AI_feeding': (context) => AiFeedSettingPage(),
        '/self_feeding': (context) => SelfFeedingPage(),
        '/find_password': (context) => FindPassword(),
        '/notification_history': (context) => NotificationHistory(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
