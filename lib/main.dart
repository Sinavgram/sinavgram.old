// main.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math'; 
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http_parser/http_parser.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:timezone/data/latest.dart' as tz; 
import 'package:timezone/timezone.dart' as tz; 
import 'package:url_launcher/url_launcher.dart';
import 'package:file_saver/file_saver.dart';
// PUBSPEC.YAML GEREKSİNİMLERİ:
// flutter_local_notifications: ^17.1.2
// timezone: ^0.9.3
// ...ve diğerleri

// --- YENİ: BİLDİRİM SERVİSİ ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final Random _random = Random();

  static const List<String> _messages_0_percent = [
    "Bugün hiç soru çözmedin. Hadi ne duruyorsun? 💪",
    "Hedeflerin seni bekliyor, ilk soruyu çözerek başla!",
    "Rakiplerin çalışıyor, sen de başla! 🚀",
  ];
  static const List<String> _messages_1_25_percent = [
    "Başlamak bitirmenin yarısıdır, harika başlangıç! ✨",
    "İlk adımı attın, devamı gelecek! Unutma, her soru bir adımdır.",
    "Güzel başlangıç, bu momentumu kaybetme!",
  ];
  static const List<String> _messages_26_74_percent = [
    "Yolun yarısı, pes etmek yok! Harika gidiyorsun. 👏",
    "Çalışmaya devam, emeğinin karşılığını alacaksın!",
    "Harika bir ilerleme! Hedefe adım adım yaklaşıyorsun.",
  ];
  static const List<String> _messages_75_100_percent = [
    "Yüzdün yüzdün kuyruğuna geldin, hedefi tamamlamaya çok az kaldı! 🎉",
    "Az daha gayret, günlük hedefini tamamlamak üzeresin!",
    "Harika bir performans, son birkaç soruyla günü tamamla! 🏆",
  ];

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS, 
  );

    await _notificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("Tüm bildirimler iptal edildi.");
  }

  static Future<void> scheduleDailyNotifications() async {
    await cancelAllNotifications();
    
    final bool notificationsEnabled = await SettingsService.getNotificationsEnabled();
    if (!notificationsEnabled) {
      debugPrint("Bildirimler kapalı, planlama yapılmadı.");
      return;
    }

    final int goal = await DailyGoalService.getGoal();
    final int solved = await DailyGoalService.getSolvedCount();
    final double progress = goal > 0 ? (solved / goal) * 100 : 0;

    List<String> messages;
    if (progress == 0) {
      messages = _messages_0_percent;
    } else if (progress <= 25) {
      messages = _messages_1_25_percent;
    } else if (progress <= 74) {
      messages = _messages_26_74_percent;
    } else {
      messages = _messages_75_100_percent;
    }

    final String randomMessage = messages[_random.nextInt(messages.length)];

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sinavgram_channel_id',
      'Sınavgram Hatırlatıcıları',
      channelDescription: 'Günlük soru çözme hatırlatmaları',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    final List<int> hours = [9, 12, 15, 18, 21];
    for (int i = 0; i < hours.length; i++) {
      await _notificationsPlugin.zonedSchedule(
        i,
        'Sınavgram Seni Bekliyor!',
        randomMessage,
        _nextInstanceOfTime(hours[i]),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint("${hours[i]}:00 için bildirim planlandı: $randomMessage");
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}


// --- REKLAM SERVİSİ ---
class AdService {
  InterstitialAd? _interstitialAd;

  // YENİ: Sınavdan çıkış sayısını takip etmek için anahtar
  static const String _quizExitCountKey = 'quiz_exit_count';

  static final String bannerAdUnitId = Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/6300978111' // Android Banner Test ID
    : 'ca-app-pub-3940256099942544/2934735716'; // iOS Banner Test ID

  static final String interstitialAdUnitId = Platform.isAndroid
    ? 'ca-app-pub-3940256099942544/1033173712' // Android Interstitial Test ID
    : 'ca-app-pub-3940256099942544/4411468910'; // iOS Interstitial Test ID

  // YENİ: Sınavdan çıkışta reklam gösterilip gösterilmeyeceğini kontrol eden metot
  Future<bool> shouldShowAdOnQuizExit() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_quizExitCountKey) ?? 0;
    currentCount++;

    if (currentCount >= 5) {
      await prefs.setInt(_quizExitCountKey, 0); // Sayacı sıfırla
      debugPrint("Reklam gösterilecek. Sayaç sıfırlandı.");
      return true; // Reklam gösterme zamanı
    } else {
      await prefs.setInt(_quizExitCountKey, currentCount); // Artırılmış sayıyı kaydet
      debugPrint("Reklam gösterilmeyecek. Sayaç: $currentCount");
      return false; // Henüz zamanı değil
    }
  }

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('InterstitialAd yüklenemedi: $err');
        },
      ),
    );
  }
  
  void showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          loadInterstitialAd();
        }
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
        loadInterstitialAd();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}

// --- BANNER REKLAM WIDGET'I ---
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPremium = context.watch<UserProvider>().isPremium;
    if (!isPremium) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd yüklenemedi: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}


// --- KULLANICI VERİ YÖNETİMİ (PROVIDER) ---
class UserProvider with ChangeNotifier {
  Map<String, dynamic> _userData = {};

  Map<String, dynamic> get userData => _userData;
  int get score => _userData['score'] ?? 0;
  String get username => _userData['username'] ?? 'Kullanıcı';
  String? get avatarUrl => _userData['avatar_url'];
  
  int? get rank => _userData['rank'];
  int? get totalUsers => _userData['total_users'];
  List<dynamic> get badges => _userData['badges'] as List<dynamic>? ?? [];

  bool get isPremium => false; 

  void setUser(Map<String, dynamic> userData) {
    _userData = userData;
    notifyListeners();
  }

  void updateScore(int newScore) {
    _userData['score'] = newScore;
    notifyListeners();
  }
    
  void updateUserPartial(Map<String, dynamic> data) {
      _userData['username'] = data['username'] ?? _userData['username'];
      _userData['avatar_url'] = data['avatar_url'] ?? _userData['avatar_url'];
      notifyListeners();
  }
}

// --- GÜNLÜK HEDEF SERVİSİ ---
class DailyGoalService {
  static const String _goalKey = 'daily_goal';
  static const String _countKey = 'daily_solved_count';
  static const String _dateKey = 'daily_count_date';

  static Future<void> setGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, goal);
  }

  static Future<int> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey) ?? 100;
  }

  static Future<int> getSolvedCount() async {
    await _resetIfNewDay();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_countKey) ?? 0;
  }

  static Future<void> incrementSolvedCount() async {
    await _resetIfNewDay();
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_countKey) ?? 0;
    await prefs.setInt(_countKey, currentCount + 1);
  }

  static Future<void> _resetIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDate = prefs.getString(_dateKey);

    if (lastDate != today) {
      await prefs.setInt(_countKey, 0);
      await prefs.setString(_dateKey, today);
    }
  }
}

// --- YEREL ANALİZ SERVİSİ ---
class LocalAnalyticsService {
  static const String _recordsKey = 'analytics_records';

  static Future<void> addAnswerRecord({
    required int courseId,
    required String courseName,
    required String subtopicName,
    int? subtopicId,
    String? pdfUrl,
    required bool isCorrect,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final newRecord = {
      'course_id': courseId,
      'course_name': courseName,
      'subtopic_name': subtopicName,
      'subtopic_id': subtopicId,
      'pdf_url': pdfUrl,
      'is_correct': isCorrect,
      'timestamp': DateTime.now().toIso8601String(),
    };

    List<dynamic> records = await getRecords();
    records.add(newRecord);
    
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    records.removeWhere((r) => DateTime.parse(r['timestamp']).isBefore(thirtyDaysAgo));

    await prefs.setString(_recordsKey, json.encode(records));
  }

  static Future<List<dynamic>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsString = prefs.getString(_recordsKey);
    if (recordsString != null) {
      return json.decode(recordsString) as List<dynamic>;
    }
    return [];
  }

  static Future<Map<String, dynamic>?> analyzeWeakestCourse() async {
    List<dynamic> records = await getRecords();
    if (records.isEmpty) return null;

    final incorrectCounts = <String, Map<String, dynamic>>{};
    for (var record in records) {
      if (record['is_correct'] == false) {
        final courseName = record['course_name'] as String;
        final courseId = record['course_id'] as int?;
        if (courseId != null) {
          incorrectCounts[courseName] = {
            'count': (incorrectCounts[courseName]?['count'] ?? 0) + 1,
            'course_id': courseId,
            'course_name': courseName,
          };
        }
      }
    }

    if (incorrectCounts.isEmpty) return null;

    final weakestCourse = incorrectCounts.values.reduce((a, b) => a['count'] > b['count'] ? a : b);
    return weakestCourse;
  }

  static Future<Map<String, dynamic>?> analyzeWeakestSubtopicLast7Days() async {
    List<dynamic> records = await getRecords();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final recentRecords = records.where((r) {
      final timestamp = DateTime.parse(r['timestamp']);
      return timestamp.isAfter(sevenDaysAgo);
    }).toList();

    if (recentRecords.isEmpty) return null;

    final incorrectCounts = <String, Map<String, dynamic>>{};
    for (var record in recentRecords) {
      if (record['is_correct'] == false && record['subtopic_name'] != null && record['pdf_url'] != null) {
        final subtopic = record['subtopic_name'] as String;
        incorrectCounts[subtopic] = {
          'count': (incorrectCounts[subtopic]?['count'] ?? 0) + 1,
          'pdf_url': record['pdf_url'],
          'subtopic_name': subtopic,
        };
      }
    }

    if (incorrectCounts.isEmpty) return null;

    final weakestSubtopic = incorrectCounts.values.reduce((a, b) => a['count'] > b['count'] ? a : b);
    return weakestSubtopic;
  }
}

// --- AYARLAR SERVİSİ ---
class SettingsService {
  static const String _notificationsKey = 'notifications_enabled';
  static const String _themeColorKey = 'theme_color';

  static Future<void> setNotificationsEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, isEnabled);
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }
  
  static Future<void> setThemeColor(String colorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, colorName);
  }

  static Future<String> getThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeColorKey) ?? 'Mor';
  }
}

// --- TEMA YÖNETİCİSİ (PROVIDER) ---
class ThemeNotifier with ChangeNotifier {
  ThemeData _themeData;
  ThemeData get themeData => _themeData;

  ThemeNotifier(this._themeData);

  static final Map<String, Color> themeColors = {
    'Mor': Colors.deepPurple,
    'Mavi': Colors.blue,
    'Yeşil': Colors.green,
  };
  
  static ThemeData _createThemeData(Color primaryColor) {
     return ThemeData(
        primarySwatch: primaryColor as MaterialColor,
        primaryColor: primaryColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
        )
      );
  }

  void setTheme(String colorName) async {
    final color = themeColors[colorName] ?? Colors.deepPurple;
    _themeData = _createThemeData(color);
    await SettingsService.setThemeColor(colorName);
    notifyListeners();
  }
}


// --- API SERVİSİ ---
class ApiService {
  static const String _baseUrl = "your_api_base_url_here";
  static String? _token;

  static Future<Map<String, dynamic>> deleteAccount() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/legal/delete-my-account'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<String> downloadMyData() async {
    var request = http.Request('GET', Uri.parse('$_baseUrl/legal/download-my-data'));
    request.headers.addAll(await _getHeaders());
    
    final http.StreamedResponse streamedResponse = await request.send();

    if (streamedResponse.statusCode == 200) {
      final Uint8List bytes = await streamedResponse.stream.toBytes();
      
      String filename = 'sınavgram_verilerim.json';
      final String? contentDisposition = streamedResponse.headers['content-disposition'];
      if (contentDisposition != null) {
        final RegExp regExp = RegExp('filename="(.+?)"');
        final Match? match = regExp.firstMatch(contentDisposition);
        if (match != null) {
          filename = match.group(1)!;
        }
      }

      String? savedPath = await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json
      );
      return savedPath;
    } else {
      final responseBody = await streamedResponse.stream.bytesToString();
      final errorData = json.decode(responseBody);
      throw Exception(errorData['message'] ?? 'Veri indirilemedi.');
    }
  }

  static Future<void> subscribeToNewsletter(String email) async {
    await http.post(
      Uri.parse('$_baseUrl/community/add-email'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
  }
  
  static String getFullUrl(String? relativeUrl) {
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return 'https://placehold.co/100x100/663399/FFFFFF?text=SG'; 
    }
    if (relativeUrl.startsWith('http')) {
        return relativeUrl;
    }
    return _baseUrl + relativeUrl;
  }

  static Future<Map<String, String>> _getHeaders() async {
    await loadToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'};
  }
    
  static Future<Map<String, String>> _getAuthHeaderOnly() async {
      await loadToken();
      return {'Authorization': 'Bearer $_token'};
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token); _token = token;
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); _token = null;
  }
  
  static Future<dynamic> _handleResponse(http.Response response) async {
      if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) return null;
          return json.decode(utf8.decode(response.bodyBytes));
      } else {
          final errorData = json.decode(utf8.decode(response.bodyBytes));
          throw Exception(errorData['message'] ?? 'Bilinmeyen bir hata oluştu.');
      }
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'email': email, 'password': password}),
    );
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identifier': identifier, 'password': password}),
    );
    final responseData = await _handleResponse(response);
    if (responseData.containsKey('token')) {
      await saveToken(responseData['token']);
    }
    return responseData;
  }
  
  static Future<List<dynamic>> getCourses() async {
    final response = await http.get(Uri.parse('$_baseUrl/api/courses'), headers: await _getHeaders());
    return await _handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> getSubtopics(int courseId) async {
    final response = await http.get(Uri.parse('$_baseUrl/api/course/$courseId/subtopics'), headers: await _getHeaders());
    return await _handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> getQuestions(int courseId, {int? subtopicId}) async {
    String url = '$_baseUrl/api/questions/bulk/$courseId?limit=20';
    if (subtopicId != null) {
      url += '&subtopic_id=$subtopicId';
    }
    final response = await http.get(Uri.parse(url), headers: await _getHeaders());
    return await _handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> submitAnswer(int questionId, String selectedOption) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/submit-answer'), headers: await _getHeaders(), body: json.encode({'questionId': questionId, 'selectedOption': selectedOption}));
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleLike(int questionId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/questions/$questionId/like'), headers: await _getHeaders());
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleSave(int questionId) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/questions/$questionId/save'), headers: await _getHeaders());
    return await _handleResponse(response) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getMyProfile() async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/profile/me'), headers: await _getHeaders());
      return await _handleResponse(response) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getUserStats() async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/stats'), headers: await _getHeaders());
      return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getUserProfile(int userId, {int page = 1}) async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/profile/$userId?page=$page'), headers: await _getHeaders());
      return await _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getQuestionByLinkId(String linkId) async {
      final response = await http.get(Uri.parse('$_baseUrl/api/questions/share/$linkId'), headers: await _getHeaders());
      return await _handleResponse(response);
  }
  
  static Future<List<dynamic>> getLikedQuestions() async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/liked-questions'), headers: await _getHeaders());
      return await _handleResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> getSavedQuestions() async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/saved-questions'), headers: await _getHeaders());
      return await _handleResponse(response) as List<dynamic>;
  }
  
  static Future<List<dynamic>> getSubmittedQuestions() async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/submitted-questions?status=approved'), headers: await _getHeaders());
      return await _handleResponse(response) as List<dynamic>;
  }
  
  static Future<List<dynamic>> searchQuestions(String query) async {
      final response = await http.get(Uri.parse('$_baseUrl/api/search/questions?q=$query'), headers: await _getHeaders());
      return await _handleResponse(response) as List<dynamic>;
  }
  
  static Future<List<dynamic>> searchUsers(String query) async {
      final response = await http.get(Uri.parse('$_baseUrl/api/user/search/users?q=$query'), headers: await _getHeaders());
      return await _handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/auth/resend-verification-email'), headers: {'Content-Type': 'application/json'}, body: json.encode({'email': email}));
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitQuestion(Map<String, String> fields, XFile? imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/questions/submit'));
    request.headers.addAll(await _getAuthHeaderOnly());
    request.fields.addAll(fields);

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path, contentType: MediaType('image', 'jpeg')));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    return await _handleResponse(response) as Map<String, dynamic>;
  }
    
  static Future<Map<String, dynamic>> updateUserProfile(String? username, XFile? avatarFile) async {
      var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/api/user/profile/me/update'));
      request.headers.addAll(await _getAuthHeaderOnly());

      if (username != null && username.isNotEmpty) request.fields['username'] = username;
      if (avatarFile != null) request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path, contentType: MediaType('image', 'jpeg')));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      return await _handleResponse(response) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/auth/password-reset/request'), headers: {'Content-Type': 'application/json'}, body: json.encode({'email': email}));
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> reportQuestion(int questionId, String reason) async {
    final response = await http.post(Uri.parse('$_baseUrl/api/questions/report'), headers: await _getHeaders(), body: json.encode({'question_id': questionId, 'reason': reason}));
    return await _handleResponse(response) as Map<String, dynamic>;
  }
  
  static Future<Map<String, dynamic>> getAiSolutionPayload(int questionId, String userSelectedOption) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/ai/solve-question'),
      headers: await _getHeaders(),
      body: json.encode({
        'question_id': questionId,
        'user_selected_option': userSelectedOption,
      }),
    );
    return await _handleResponse(response) as Map<String, dynamic>;
  }

  static Future<String> fetchGeminiSolution(String url, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    final responseData = await _handleResponse(response);
    
    if (responseData != null &&
        responseData['candidates'] != null &&
        (responseData['candidates'] as List).isNotEmpty &&
        responseData['candidates'][0]['content'] != null &&
        responseData['candidates'][0]['content']['parts'] != null &&
        (responseData['candidates'][0]['content']['parts'] as List).isNotEmpty) {
      return responseData['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception('Yapay zekadan geçersiz yanıt formatı.');
    }
  }
  
  static Future<Map<String, dynamic>> getUserRank() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/user/get-rank'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response) as Map<String, dynamic>;
  }
}

// --- UYGULAMA BAŞLANGICI ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await NotificationService.init(); 
  
  final String savedTheme = await SettingsService.getThemeColor();
  final Color primaryColor = ThemeNotifier.themeColors[savedTheme] ?? Colors.deepPurple;
  final initialTheme = ThemeNotifier._createThemeData(primaryColor);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => ThemeNotifier(initialTheme)),
        Provider<AdService>(create: (_) => AdService(), dispose: (_, adService) => adService.dispose()),
      ],
      child: const SinavgramApp(),
    ),
  );
}

class SinavgramApp extends StatelessWidget {
  const SinavgramApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'Sınavgram',
      debugShowCheckedModeBanner: false,
      theme: themeNotifier.themeData,
      home: const AuthWrapper(),
    );
  }
}

// --- GİRİŞ KONTROL VE YÖNLENDİRME ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    _appLinks = AppLinks();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleDeepLink(uri, isFromColdStart: false);
      }
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri, isFromColdStart: true);
        return;
      }
    } catch (e) {
      debugPrint('Başlangıç URI alınamadı: $e');
    }
    
    _checkLogin();
  }

  void _handleDeepLink(Uri uri, {required bool isFromColdStart}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      if (uri.host == 'login') {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      else if (uri.host == 'question' && uri.pathSegments.isNotEmpty) {
        final linkId = uri.pathSegments.first;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: linkId)));
      }
    });
  }

  Future<void> _checkLogin() async {
    if (!mounted) return;
    await ApiService.loadToken();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      try {
        final profileData = await ApiService.getMyProfile();
        if (mounted) {
          Provider.of<UserProvider>(context, listen: false).setUser(profileData);
          await NotificationService.scheduleDailyNotifications(); 
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
        }
      } catch (e) {
        await ApiService.clearToken();
        if(mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } else {
        if(mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// --- GİRİŞ EKRANI ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final result = await ApiService.login(_identifierController.text, _passwordController.text);
        if (mounted) {
          if (result['email_not_verified'] == true) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: result['email'])));
          } else if (result.containsKey('token') && result.containsKey('user')) {
            Provider.of<UserProvider>(context, listen: false).setUser(result['user']); 
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sınavgram\'a Hoş Geldiniz!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                const SizedBox(height: 8),
                Text('Giriş yaparak devam edin', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _identifierController,
                  decoration: InputDecoration(labelText: 'E-posta veya Kullanıcı Adı', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  validator: (value) => value!.isEmpty ? 'Lütfen bu alanı doldurun' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value!.isEmpty ? 'Lütfen şifrenizi girin' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    child: const Text('Şifremi Unuttum'),
                  ),
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('Giriş Yap'),
                      ),
                const SizedBox(height: 16),
                Center(
                  child: RichText(
                    text: TextSpan(
                      text: 'Hesabınız yok mu? ',
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      children: [
                        TextSpan(
                          text: 'Kayıt Olun',
                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        ),
                      ],
                    ),
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

// --- KAYIT EKRANI ---
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _agreedToTerms = false;
  bool _subscribeToNewsletter = false;
  
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: $url')),
        );
      }
    }
  }

  /// Kayıt işlemini gerçekleştirir ve başarılı olursa OnboardingScreen'e yönlendirir.
  Future<void> _register() async {
    // 1. Kullanım şartlarının kabul edilip edilmediğini kontrol et
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Devam etmek için Kullanım Şartları ve Gizlilik Politikası\'nı kabul etmelisiniz.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Formun geçerli olup olmadığını kontrol et
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 3. SADECE kayıt servisini çağır. Artık login servisi çağrılmıyor.
        final result = await ApiService.register(
            _usernameController.text, 
            _emailController.text, 
            _passwordController.text
        );
        
        // 4. API yanıtında 'token' ve 'user' olup olmadığını kontrol et.
        // Bu, kaydın başarılı olduğu VE sunucunun bize oturum bilgisi döndürdüğü anlamına gelir.
        if (mounted && result.containsKey('token') && result.containsKey('user')) {
          
          // Bülten aboneliği istenmişse, aboneliği gerçekleştir.
          if (_subscribeToNewsletter) {
            try {
              await ApiService.subscribeToNewsletter(_emailController.text.trim());
            } catch (e) {
              // Bu hatanın ana akışı engellememesi için sadece debug konsoluna yazdırılır.
              debugPrint("Bülten aboneliği sırasında hata: $e");
            }
          }

          // 5. Kullanıcı bilgilerini Provider ile uygulama geneline tanıt.
          Provider.of<UserProvider>(context, listen: false).setUser(result['user']);
          
          // Bildirimleri zamanla.
          await NotificationService.scheduleDailyNotifications(); 
          
          // 6. Kullanıcıyı doğrudan Onboarding ekranına yönlendir ve geri dönememesini sağla.
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()), 
            (route) => false
          );

        } else {
          // Eğer API'den 'token' veya 'user' gelmediyse, bir hata vardır.
          // Sunucudan gelen hata mesajını göster.
          if(mounted) {
            final errorMessage = result['message'] ?? 'Bilinmeyen bir hata oluştu.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red)
            );
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()), 
            (route) => false
          );
        }

      } catch (e) {
        // API çağrısı sırasında bir ağ hatası veya başka bir istisna oluşursa yakala.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bir hata oluştu: ${e.toString()}'), backgroundColor: Colors.red)
          );
        }
      } finally {
        // İşlem başarılı da olsa, başarısız da olsa yüklenme animasyonunu durdur.
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap Oluştur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _usernameController, decoration: InputDecoration(labelText: 'Kullanıcı Adı', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (value) => value!.isEmpty ? 'Kullanıcı adı gerekli' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, decoration: InputDecoration(labelText: 'E-posta', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.emailAddress, validator: (value) => value!.isEmpty || !value.contains('@') ? 'Geçerli bir e-posta girin' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Şifre', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), validator: (value) => value!.length < 6 ? 'Şifre en az 6 karakter olmalı' : null),
              const SizedBox(height: 16),
              
              CheckboxListTile(
                title: const Text("Gelişmelerden haberdar olmak için bültene abone ol.", style: TextStyle(fontSize: 14)),
                value: _subscribeToNewsletter,
                onChanged: (bool? value) {
                  setState(() {
                    _subscribeToNewsletter = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (bool? value) {
                      setState(() {
                        _agreedToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Kullanım Şartları',
                            style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => _launchURL('https://sinavgram.com/legal/terms-of-service'),
                          ),
                          const TextSpan(text: ' ve '),
                          TextSpan(
                            text: 'Gizlilik Politikası',
                            style: TextStyle(color: Theme.of(context).primaryColor, decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()..onTap = () => _launchURL('https://sinavgram.com/legal/privacy-policy'),
                          ),
                          const TextSpan(text: '\'nı okudum ve kabul ediyorum.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _register, 
                    child: const Text('Kayıt Ol')
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TANITIM EKRANI ---
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Widget> _buildPages(BuildContext context) {
    final username = Provider.of<UserProvider>(context, listen: false).username;
    
    return [
      _buildPage(
        icon: Icons.waving_hand,
        title: 'Sınavgram\'a Hoş Geldin, $username!',
        content: 'Sınavlara hazırlık yolculuğunda yeni partnerin burada. Başlamak için kaydır!',
      ),
      _buildPage(
        icon: Icons.checklist,
        title: 'Uygulama Nasıl Çalışır?',
        content: '• Panelim ile gelişimini anlık takip et.\n• Ders ve konu seçerek binlerce soru çöz.\n• PDF notları ile konularını pekiştir.\n• Çözemediğin soruları kaydet, sonra tekrar dene.',
        isList: true,
      ),
      _buildPage(
        icon: Icons.star_rate,
        title: 'Puan Sistemi Nasıl Çalışır?',
        content: '• Her doğru cevap için +1000 Puan kazanırsın.\n• Her yanlış cevap için -250 Puan kaybedersin.\n\nPuanını yükselterek sıralamada üste çık!',
        isList: true,
      ),
    ];
  }

  Widget _buildPage({required IconData icon, required String title, required String content, bool isList = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          const SizedBox(height: 32),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            content,
            textAlign: isList ? TextAlign.start : TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (index) => _buildDot(index: index)),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == pages.length - 1) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(_currentPage == pages.length - 1 ? 'Hadi Başlayalım!' : 'İleri'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? Theme.of(context).primaryColor : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// --- ANA EKRAN (NAVİGASYON YÖNETİCİSİ) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  late final AdService _adService;

  static const List<Widget> _widgetOptions = <Widget>[
    PanelimScreen(),
    CoursesScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _adService = Provider.of<AdService>(context, listen: false);
    _adService.loadInterstitialAd();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      floatingActionButton: _selectedIndex == 3
        ? FloatingActionButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubmitQuestionScreen())), tooltip: 'Soru Gönder', child: const Icon(Icons.add))
        : null,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Panelim'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Dersler'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Ara'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- PANELİM EKRANI (DASHBOARD) ---
class PanelimScreen extends StatefulWidget {
  const PanelimScreen({super.key});

  @override
  State<PanelimScreen> createState() => _PanelimScreenState();
}

class _PanelimScreenState extends State<PanelimScreen> {
  Map<String, dynamic>? _weakestCourse;
  Map<String, dynamic>? _weakestSubtopic;
  Map<String, dynamic>? _randomQuestion;
  int _dailyGoal = 100;
  int _dailySolvedCount = 0;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // API ve yerel servis çağrılarını aynı anda başlat
      final profileFuture = ApiService.getMyProfile();
      final rankFuture = ApiService.getUserRank();
      final randomQuestionFuture = _fetchRandomInteractionQuestion();
      final dailyGoalFuture = DailyGoalService.getGoal();
      final dailySolvedFuture = DailyGoalService.getSolvedCount();
      final weakestCourseFuture = LocalAnalyticsService.analyzeWeakestCourse();
      final weakestSubtopicFuture = LocalAnalyticsService.analyzeWeakestSubtopicLast7Days();

      // Tüm sonuçların tamamlanmasını bekle
      final results = await Future.wait([
        profileFuture,
        rankFuture,
        randomQuestionFuture,
        dailyGoalFuture,
        dailySolvedFuture,
        weakestCourseFuture,
        weakestSubtopicFuture,
      ]);

      if (mounted) {
        final profileData = results[0] as Map<String, dynamic>?;
        final rankData = results[1] as Map<String, dynamic>?;

        if (profileData != null && rankData != null) {
          profileData.addAll(rankData);
        }
        
        if (profileData != null) {
          Provider.of<UserProvider>(context, listen: false).setUser(profileData);
        }

        setState(() {
          _randomQuestion = results[2] as Map<String, dynamic>?;
          _dailyGoal = results[3] as int;
          _dailySolvedCount = results[4] as int;
          _weakestCourse = results[5] as Map<String, dynamic>?;
          _weakestSubtopic = results[6] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Veriler yüklenirken bir hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchRandomInteractionQuestion() async {
    try {
      final likedFuture = ApiService.getLikedQuestions();
      final savedFuture = ApiService.getSavedQuestions();

      final results = await Future.wait([likedFuture, savedFuture]);

      final List<dynamic> liked = results[0];
      final List<dynamic> saved = results[1];

      final allQuestions = <String, dynamic>{};
      for (var q in liked) { allQuestions[q['id'].toString()] = q; }
      for (var q in saved) { allQuestions[q['id'].toString()] = q; }

      final uniqueQuestions = allQuestions.values.toList();

      if (uniqueQuestions.isNotEmpty) {
        final random = Random();
        return uniqueQuestions[random.nextInt(uniqueQuestions.length)];
      }
      return null;
    } catch (e) {
      debugPrint("Rastgele soru çekilirken hata: $e");
      return null;
    }
  }

  Future<void> _showEditGoalDialog() async {
    final goalController = TextEditingController(text: _dailyGoal.toString());
    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Günlük Hedefi Düzenle'),
          content: TextField(
            controller: goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Günlük Soru Hedefi'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final goal = int.tryParse(goalController.text);
                if (goal != null && goal > 0) {
                  Navigator.of(context).pop(goal);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (newGoal != null && mounted) {
      await DailyGoalService.setGoal(newGoal);
      setState(() {
        _dailyGoal = newGoal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panelim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_error!)))
                    : RefreshIndicator(
                        onRefresh: _loadDashboardData,
                        child: ListView(
                          padding: const EdgeInsets.all(8.0),
                          children: [
                            _buildWelcomeCard(user),
                            _buildQuickStatCards(user.score, user.rank),
                            _buildDailyGoalCard(_dailySolvedCount, _dailyGoal),
                            if (_weakestCourse != null)
                              _buildWeakestSubjectCard(_weakestCourse!),
                            if (_weakestSubtopic != null)
                              _buildWeakestSubtopicCard(_weakestSubtopic!),
                            if (_randomQuestion != null) _buildRandomQuestionCard(_randomQuestion!),
                            const SuccessTipsCard(),
                          ],
                        ),
                      ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(UserProvider user) {
    return Card(
      elevation: 0,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: CachedNetworkImageProvider(ApiService.getFullUrl(user.avatarUrl)),
              child: user.avatarUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Merhaba, ${user.username}!',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Bugün hedeflerine ulaşmak için harika bir gün.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCards(int score, int? rank) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    score.toString(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 4),
                  const Text('Puan', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    rank != null ? '#$rank' : '-',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 4),
                  const Text('Sıralama', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyGoalCard(int solved, int goal) {
    final double progress = goal > 0 ? (solved / goal).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Günün Hedefi', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onPressed: _showEditGoalDialog,
                  tooltip: 'Hedefi Düzenle',
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$solved / $goal', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakestSubjectCard(Map<String, dynamic> weakestCourse) {
    final subjectName = weakestCourse['course_name'] ?? 'Bilinmeyen Ders';
    final courseId = weakestCourse['course_id'];
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text("Bu Derse Yüklen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'En çok yanlışın "$subjectName" dersinde görünüyor. Netlerini artırmak için harika bir fırsat!',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (courseId != null) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(courseId: courseId, courseName: subjectName)));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
                child: Text('$subjectName Soruları Çöz'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakestSubtopicCard(Map<String, dynamic> weakestSubtopic) {
    final subtopicName = weakestSubtopic['subtopic_name'] ?? 'Bilinmeyen Konu';
    final pdfUrl = weakestSubtopic['pdf_url'];

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: Colors.orange[800]),
                const SizedBox(width: 8),
                const Text("Konu Tekrarı Önerisi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Son 1 haftada en çok "$subtopicName" konusunda zorlandın. Konu anlatımına göz atmaya ne dersin?',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: ApiService.getFullUrl(pdfUrl), title: subtopicName)));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
                child: const Text('Konu Anlatımını Aç'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomQuestionCard(Map<String, dynamic> question) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: question['link_id'])));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.replay_circle_filled, color: Colors.grey),
                  SizedBox(width: 8),
                  Text("Tekrar Göz At", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                question['text'] ?? 'Soru metni bulunamadı.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  question['course_name'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SuccessTipsCard extends StatefulWidget {
  const SuccessTipsCard({super.key});

  @override
  State<SuccessTipsCard> createState() => _SuccessTipsCardState();
}

class _SuccessTipsCardState extends State<SuccessTipsCard> {
  static const List<String> _tips = [
    "Her gün belirli bir saatte çalışmak, düzenli bir alışkanlık kazanmanıza yardımcı olur.",
    "Çözemediğiniz soruların üzerine gitmek, en kalıcı öğrenmeyi sağlar. Pes etmeyin!",
    "Konu tekrarı yaparken sadece okumak yerine, küçük notlar alarak veya özet çıkararak çalışın.",
    "Pomodoro tekniğini deneyin: 25 dakika ders, 5 dakika mola. Bu, odaklanmanızı artırır.",
    "Deneme sınavı sonuçlarınızı analiz ederek en çok yanlış yaptığınız konuları belirleyin ve onlara öncelik verin.",
    "Yeterli ve kaliteli uyku, öğrendiklerinizin kalıcı hale gelmesi için çok önemlidir.",
    "Farklı kaynaklardan soru çözmek, farklı soru tiplerine alışmanızı sağlar.",
    "Kendinize gerçekçi hedefler koyun ve bu hedeflerine ulaştığınızda kendinizi küçük ödüllerle motive edin."
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = Random().nextInt(_tips.length);
  }

  void _nextTip() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _tips.length;
    });
  }

  void _previousTip() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _tips.length) % _tips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 8),
                Text("Günün İpucu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _tips[_currentIndex],
              style: const TextStyle(fontSize: 15, height: 1.4),
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: _previousTip,
                  iconSize: 16,
                  color: Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: _nextTip,
                  iconSize: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// --- DERSLER EKRANI ---
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late Future<List<dynamic>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _coursesFuture = ApiService.getCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dersler')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _coursesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Gösterilecek ders bulunamadı.'));
          
                final courses = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        title: Text(course['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).primaryColor),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SubtopicScreen(courseId: course['id'], courseName: course['name']))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

// --- ALT KONU EKRANI ---
class SubtopicScreen extends StatefulWidget {
  final int courseId;
  final String courseName;

  const SubtopicScreen({super.key, required this.courseId, required this.courseName});

  @override
  State<SubtopicScreen> createState() => _SubtopicScreenState();
}

class _SubtopicScreenState extends State<SubtopicScreen> {
  late Future<List<dynamic>> _subtopicsFuture;

  @override
  void initState() {
    super.initState();
    _subtopicsFuture = ApiService.getSubtopics(widget.courseId);
  }

  void _onSubtopicTap(Map<String, dynamic> subtopic) {
    String? pdfUrl = subtopic['pdf_url'];
    
    if (pdfUrl != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(subtopic['name']),
          content: const Text('Ne yapmak istersiniz?'),
          actions: [
            TextButton(child: const Text('PDF Görüntüle'), onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfUrl: ApiService.getFullUrl(pdfUrl), title: subtopic['name'])));
            }),
            ElevatedButton(child: const Text('Sınavı Başlat'), onPressed: () {
              Navigator.of(ctx).pop();
              _startQuiz(subtopicId: subtopic['id'], pdfUrl: pdfUrl);
            }),
          ],
        ),
      );
    } else {
      _startQuiz(subtopicId: subtopic['id']);
    }
  }

  void _startQuiz({int? subtopicId, String? pdfUrl}) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizScreen(
        courseId: widget.courseId, 
        subtopicId: subtopicId, 
        courseName: widget.courseName,
        subtopicPdfUrl: pdfUrl,
      )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.courseName)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shuffle),
                label: const Text('Tüm Konulardan Karışık Çöz'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                onPressed: () => _startQuiz(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _subtopicsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Bu derse ait alt konu bulunamadı.'));
                
                final subtopics = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: subtopics.length,
                  itemBuilder: (context, index) {
                    final subtopic = subtopics[index];
                    final bool hasPdf = subtopic['pdf_url'] != null;
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ListTile(
                        title: Text(subtopic['name']),
                        subtitle: Text(hasPdf ? "PDF mevcut. Görüntülemek için dokunun." : "Sınavı başlatmak için dokunun."),
                        trailing: hasPdf ? const Icon(Icons.picture_as_pdf, color: Colors.red) : const Icon(Icons.quiz),
                        onTap: () => _onSubtopicTap(subtopic),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

// --- SINAV EKRANI ---
class QuizScreen extends StatefulWidget {
  final int courseId;
  final int? subtopicId;
  final String courseName;
  final String? subtopicPdfUrl;

  const QuizScreen({
    super.key, 
    required this.courseId, 
    this.subtopicId, 
    required this.courseName,
    this.subtopicPdfUrl,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late Future<List<dynamic>> _questionsFuture;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _questionsFuture = ApiService.getQuestions(widget.courseId, subtopicId: widget.subtopicId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // GÜNCELLENDİ: Sınavdan çıkış mantığı güncellendi.
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final adService = Provider.of<AdService>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // Her 5 çıkışta bir reklam göster
        final bool shouldShowAd = await adService.shouldShowAdOnQuizExit();
        if (shouldShowAd && !userProvider.isPremium) {
          adService.showInterstitialAd();
        }

        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${widget.courseName} Sınavı')),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _questionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Sorular yüklenemedi: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
                  if (!snapshot.hasData) return const Center(child: Text('Bu konuda gösterilecek soru bulunamadı.'));
          
                  final questions = snapshot.data!;
                  if (questions.isEmpty) {
                    return const QuizFinishedScreen();
                  }

                  return PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: questions.length + 1,
                    itemBuilder: (context, index) {
                      if (index < questions.length) {
                        return QuestionCard(
                          key: ValueKey(questions[index]['id']), 
                          questionData: questions[index],
                          courseId: widget.courseId,
                          courseName: widget.courseName,
                          subtopicId: widget.subtopicId,
                          subtopicPdfUrl: widget.subtopicPdfUrl,
                        );
                      } else {
                        return const QuizFinishedScreen();
                      }
                    },
                  );
                },
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

// --- TEST BİTTİ EKRANI ---
class QuizFinishedScreen extends StatelessWidget {
  const QuizFinishedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green[600], size: 80),
          const SizedBox(height: 24),
          const Text(
            'Tebrikler!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu konudaki tüm soruları tamamladınız.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Derslere Geri Dön'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}


// --- SORU KARTI WIDGET'I ---
class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int courseId;
  final String courseName;
  final int? subtopicId;
  final String? subtopicPdfUrl;

  const QuestionCard({
    super.key, 
    required this.questionData,
    required this.courseId,
    required this.courseName,
    this.subtopicId,
    this.subtopicPdfUrl,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? _selectedOption;
  bool? _isCorrect;
  String? _correctOption;
  bool _isAnswered = false;
  late bool _isLiked;
  late bool _isSaved;

  final PageController _pageController = PageController();
  String? _aiSolution;
  bool _isAiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.questionData['liked'] ?? false;
    _isSaved = widget.questionData['saved'] ?? false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleAnswer(String option) async {
    if (_isAnswered) return;
    setState(() { _selectedOption = option; _isAnswered = true; });
    try {
      final result = await ApiService.submitAnswer(widget.questionData['id'], option);
      setState(() { _isCorrect = result['is_correct']; _correctOption = result['correct_option']; });
      if(mounted) {
        Provider.of<UserProvider>(context, listen: false).updateScore(result['new_score']);
        await DailyGoalService.incrementSolvedCount();
        
        await LocalAnalyticsService.addAnswerRecord(
          courseId: widget.courseId,
          courseName: widget.courseName,
          subtopicName: widget.questionData['subtopic_name'] ?? 'Genel',
          subtopicId: widget.subtopicId,
          pdfUrl: widget.subtopicPdfUrl,
          isCorrect: result['is_correct'],
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => _isAnswered = false);
    }
  }
  
  Future<void> _toggleLike() async {
      try {
          final result = await ApiService.toggleLike(widget.questionData['id']);
          if(result.containsKey('liked')) setState(() => _isLiked = result['liked']);
      } catch (e) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
  }

  Future<void> _toggleSave() async {
      try {
          final result = await ApiService.toggleSave(widget.questionData['id']);
           if(result.containsKey('saved')) setState(() => _isSaved = result['saved']);
      } catch (e) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
  }

  Future<void> _reportQuestion() async {
    final reportReasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Soruyu Bildir'),
        content: TextField(controller: reportReasonController, decoration: const InputDecoration(hintText: 'Bildirme nedeniniz...')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (reportReasonController.text.isEmpty) return;
              try {
                await ApiService.reportQuestion(widget.questionData['id'], reportReasonController.text);
                if(mounted) {
                   Navigator.of(ctx).pop();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soru başarıyla bildirildi.'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }
  
  void _shareQuestion() {
    final linkId = widget.questionData['link_id'];
    if (linkId != null) {
      Share.share('Sınavgram\'daki bu soruya bir göz at: https://sinavgram.com/questions/share/$linkId');
    }
  }

  Future<void> _getAiSolution() async {
    if (!_isAnswered || _selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yapay zeka çözümü için önce bir cevap vermelisiniz.')),
      );
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (_aiSolution != null) return;

    setState(() {
      _isAiLoading = true;
      _aiError = null;
    });

    try {
      final payloadData = await ApiService.getAiSolutionPayload(widget.questionData['id'], _selectedOption!);
      final geminiUrl = payloadData['gemini_url'];
      final geminiPayload = payloadData['gemini_payload'];

      final solutionText = await ApiService.fetchGeminiSolution(geminiUrl, geminiPayload);

      if (mounted) {
        setState(() {
          _aiSolution = solutionText;
          _isAiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = 'Yapay zeka çözümü alınamadı: $e';
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.questionData['options'] as Map<String, dynamic>;
    final imageUrl = widget.questionData['image_url'];

    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (index == 1) {
            _getAiSolution();
          }
        },
        children: [
          _buildQuestionPage(imageUrl, options),
          _buildAiSolutionPage(),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(String? imageUrl, Map<String, dynamic> options) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.questionData['text'] ?? 'Soru metni yüklenemedi.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  if (imageUrl != null)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FullScreenImageScreen(imageUrl: ApiService.getFullUrl(imageUrl)))),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: CachedNetworkImage(imageUrl: ApiService.getFullUrl(imageUrl), placeholder: (context, url) => const CircularProgressIndicator(), errorWidget: (context, url, error) => const Icon(Icons.error), height: 150, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ...options.entries.map((entry) {
                    final optionKey = entry.key;
                    Color? buttonColor;
                    Color? textColor = Colors.black87;
                    if (_isAnswered) {
                      if (optionKey == _correctOption) {
                        buttonColor = Colors.green.withOpacity(0.3);
                        textColor = Colors.green[900];
                      } else if (optionKey == _selectedOption) {
                        buttonColor = Colors.red.withOpacity(0.3);
                        textColor = Colors.red[900];
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _handleAnswer(optionKey),
                          style: OutlinedButton.styleFrom(backgroundColor: buttonColor, side: BorderSide(color: buttonColor != null ? Colors.transparent : Theme.of(context).primaryColor)),
                          child: Align(alignment: Alignment.centerLeft, child: Text('$optionKey) ${entry.value}', style: TextStyle(color: textColor))),
                        ),
                      ),
                    );
                  }).toList(),
                  if (_isAnswered)
                    const Padding(
                      padding: EdgeInsets.only(top: 24.0),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Detaylı çözüm için sağa kaydırın", style: TextStyle(color: Colors.grey)),
                            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(onPressed: _toggleLike, icon: Icon(_isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined, color: _isLiked ? Colors.blue : Colors.grey), tooltip: 'Beğen'),
              IconButton(onPressed: _toggleSave, icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? Colors.amber[700] : Colors.grey), tooltip: 'Kaydet'),
              IconButton(onPressed: _reportQuestion, icon: const Icon(Icons.flag_outlined, color: Colors.grey), tooltip: 'Soruyu Bildir'),
              IconButton(onPressed: _shareQuestion, icon: const Icon(Icons.share, color: Colors.grey), tooltip: 'Paylaş'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAiSolutionPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology_alt, color: Colors.blue),
              SizedBox(width: 8),
              Text('Yapay Zeka Çözümü', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: _isAiLoading
                ? const Center(child: CircularProgressIndicator())
                : _aiError != null
                    ? Center(child: Text(_aiError!, style: const TextStyle(color: Colors.red)))
                    : _aiSolution != null
                        ? SingleChildScrollView(
                            child: MarkdownBody(
                              data: _aiSolution!,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 16, height: 1.5),
                                h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                strong: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : const Center(child: Text("Çözüm yükleniyor...")),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey),
                  Text("Soruya dönmek için sola kaydırın", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// --- ARAMA EKRANI ---
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;
  
  List<dynamic> _questionResults = [];
  List<dynamic> _userResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose(); _debounce?.cancel(); _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), () => _performSearch());
  }
  
  Future<void> _performSearch() async {
      if (_searchController.text.length < 3) {
          setState(() { _questionResults = []; _userResults = []; });
          return;
      }
      setState(() => _isLoading = true);
      try {
          final results = await Future.wait([ApiService.searchQuestions(_searchController.text), ApiService.searchUsers(_searchController.text)]);
          if(mounted) {
            setState(() { 
                _questionResults = results[0]; 
                _userResults = results[1]; 
            });
          }
      } catch (e) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      } finally {
          if(mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ara'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.question_answer), text: "Sorular"),
            Tab(icon: Icon(Icons.people), text: "Kullanıcılar")
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Soru veya kullanıcı ara...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator())),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _questionResults.isEmpty && !_isLoading
                    ? const Center(child: Text('Arama sonucu bulunamadı.'))
                    : ListView.builder(itemCount: _questionResults.length, itemBuilder: (context, index) {
                        final question = _questionResults[index];
                        return ListTile(
                            title: Text(question['text']), 
                            subtitle: Text(question['course_name'] ?? ''),
                            onTap: () {
                              final linkId = question['link_id'];
                              if (linkId != null) {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: linkId)));
                              }
                            }
                        );
                      }),
                _userResults.isEmpty && !_isLoading
                    ? const Center(child: Text('Arama sonucu bulunamadı.'))
                    : ListView.builder(itemCount: _userResults.length, itemBuilder: (context, index) {
                        final user = _userResults[index];
                        return ListTile(
                            leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(ApiService.getFullUrl(user['avatar_url']))), 
                            title: Text(user['username']),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: user['id']))),
                        );
                      }),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

// --- PROFİL EKRANI ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  
  @override
  void initState() {
      super.initState();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProfile());
  }

  Future<void> _refreshProfile() async {
      try {
          final profileData = await ApiService.getMyProfile();
           if(mounted) Provider.of<UserProvider>(context, listen: false).setUser(profileData);
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profil bilgileri yenilenemedi: $e')));
      }
  }

  Widget _buildProfileButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onPressed}) => ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 20)));
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim'), actions: [IconButton(onPressed: () async { await ApiService.clearToken(); if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false); }, icon: const Icon(Icons.logout), tooltip: 'Çıkış Yap')]),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.username.isEmpty) return const Center(child: CircularProgressIndicator());
          
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () async { if (await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())) == true) _refreshProfile(); },
                            child: Stack(
                              children: [
                                CircleAvatar(radius: 50, backgroundImage: CachedNetworkImageProvider(ApiService.getFullUrl(userProvider.avatarUrl)), child: userProvider.avatarUrl == null ? const Icon(Icons.person, size: 50) : null),
                                Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 16)))
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(child: Text(userProvider.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 8),
                        Center(child: Text('Puan: ${userProvider.score}', style: TextStyle(fontSize: 20, color: Colors.grey[700]))),
                        
                        RankAndBadges(
                          rank: userProvider.rank,
                          totalUsers: userProvider.totalUsers,
                          badges: userProvider.badges,
                        ),
                
                        const SizedBox(height: 20),
                        _buildProfileButton(context, icon: Icons.bar_chart, label: "İstatistiklerim", onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen()))),
                        const SizedBox(height: 12),
                        _buildProfileButton(context, icon: Icons.thumb_up, label: "Beğenilerim", onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuestionListScreen(title: "Beğenilen Sorular", questionsFuture: ApiService.getLikedQuestions())))),
                        const SizedBox(height: 12),
                        _buildProfileButton(context, icon: Icons.bookmark, label: "Kaydettiklerim", onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuestionListScreen(title: "Kaydedilen Sorular", questionsFuture: ApiService.getSavedQuestions())))),
                         const SizedBox(height: 12),
                        _buildProfileButton(context, icon: Icons.settings, label: "Ayarlar", onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        }),
                        const SizedBox(height: 24),
                        const Text("Onaylanan Sorularım", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        FutureBuilder<List<dynamic>>(
                          future: ApiService.getSubmittedQuestions(), 
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(child: Text("Onaylanmış sorunuz bulunmuyor."));
                            }
                            final questions = snapshot.data!;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: questions.length,
                              itemBuilder: (context, index) {
                                  final q = questions[index];
                                  return Card(
                                      child: ListTile(
                                          title: Text(q['text'], maxLines: 1, overflow: TextOverflow.ellipsis), 
                                          subtitle: Text(q['course_name'] ?? ''),
                                          onTap: () {
                                              final linkId = q['link_id'];
                                              if (linkId != null) {
                                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: linkId)));
                                              }
                                          },
                                      ),
                                  );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }
}

// --- DİĞER YARDIMCI EKRANLAR ---

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDownloading = false;
  bool _isDeleting = false;
  bool _notificationsEnabled = true;
  String _currentTheme = 'Mor';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await SettingsService.getNotificationsEnabled();
    final theme = await SettingsService.getThemeColor();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notifications;
        _currentTheme = theme;
      });
    }
  }

  Future<void> _downloadData() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Verilerini İndir',
      content: 'Hesabınızla ilgili tüm verilerin bir kopyasını JSON formatında indirmek istediğinizden emin misiniz?',
      confirmText: 'Evet, İndir',
    );

    if (confirmed != true) return;

    setState(() => _isDownloading = true);
    try {
      final path = await ApiService.downloadMyData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verileriniz başarıyla indirildi: $path'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Hesabı Sil',
      content: 'Bu işlem geri alınamaz! Hesabınızı ve ilişkili tüm verileri kalıcı olarak silmek istediğinizden emin misiniz?',
      confirmText: 'Evet, Sil',
      isDestructive: true,
    );
    
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final result = await ApiService.deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.green, duration: const Duration(seconds: 5)),
        );
        await ApiService.clearToken();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: isDestructive ? Colors.red : Theme.of(context).primaryColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tema Seçin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeNotifier.themeColors.keys.map((colorName) {
              return RadioListTile<String>(
                title: Text(colorName),
                value: colorName,
                groupValue: _currentTheme,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _currentTheme = value;
                    });
                    context.read<ThemeNotifier>().setTheme(value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children: [
                // Görünüm Bölümü
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text('Görünüm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.color_lens),
                    title: const Text('Uygulama Teması'),
                    subtitle: Text(_currentTheme),
                    onTap: _showThemeDialog,
                  ),
                ),
                // Bildirim Bölümü
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Text('Bildirimler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                ),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications),
                    title: const Text('Bildirimlere İzin Ver'),
                    value: _notificationsEnabled,
                    onChanged: (bool value) async {
                      await SettingsService.setNotificationsEnabled(value);
                      setState(() {
                        _notificationsEnabled = value;
                      });
                      if (value) {
                        await NotificationService.scheduleDailyNotifications();
                      } else {
                        await NotificationService.cancelAllNotifications();
                      }
                    },
                  ),
                ),
                // Hesap Yönetimi Bölümü
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Text('Hesap Yönetimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: _isDownloading ? const CircularProgressIndicator() : const Icon(Icons.download_for_offline),
                        title: const Text('Verilerimi İndir'),
                        subtitle: const Text('Hesap bilgilerinizi ve aktivitelerinizi indirin.'),
                        onTap: _isDownloading ? null : _downloadData,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: _isDeleting ? const CircularProgressIndicator() : const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Hesabımı Kalıcı Olarak Sil', style: TextStyle(color: Colors.red)),
                        subtitle: const Text('Bu işlem geri alınamaz.'),
                        onTap: _isDeleting ? null : _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}


class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ApiService.getUserStats();
  }
  
  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistiklerim')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
                if (!snapshot.hasData || (snapshot.data!['rates'] == null)) return const Center(child: Text("İstatistik bulunamadı."));
          
                final stats = snapshot.data!;
                final rates = stats['rates'] as Map<String, dynamic>? ?? {};
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ListView(
                    children: [
                      const SizedBox(height: 12),
                      _buildStatCard("Toplam Cevap", (stats['total_answered_questions'] ?? 0).toString(), Icons.question_answer),
                      const SizedBox(height: 8),
                      _buildStatCard("Doğru Cevap", (stats['correctly_answered_questions'] ?? 0).toString(), Icons.check_circle_outline),
                      const SizedBox(height: 8),
                      _buildStatCard("Yanlış Cevap", (stats['incorrectly_answered_questions'] ?? 0).toString(), Icons.highlight_off),
                      const SizedBox(height: 8),
                      _buildStatCard("Doğruluk Oranı", "%${rates['true'] ?? 0.0}", Icons.pie_chart),
                       const SizedBox(height: 8),
                      _buildStatCard("Başarı Yüzdesi", "%${stats['accuracy_rate_excluding_blanks'] ?? 0.0}", Icons.trending_up),
                       const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class QuestionListScreen extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> questionsFuture;
  
  const QuestionListScreen({super.key, required this.title, required this.questionsFuture});

  @override
  State<QuestionListScreen> createState() => _QuestionListScreenState();
}

class _QuestionListScreenState extends State<QuestionListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: widget.questionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Gösterilecek soru bulunamadı."));
          
                final questions = snapshot.data!;
                return ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(question['text'], maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(question['course_name'] ?? 'Bilinmeyen Ders'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: question['link_id']))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
    final String email;
    const VerifyEmailScreen({super.key, required this.email});

    @override
    State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
    bool _isLoading = false;

    Future<void> _resendEmail() async {
        setState(() => _isLoading = true);
        try {
            final result = await ApiService.resendVerificationEmail(widget.email);
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
        } catch (e) {
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        } finally {
            if(mounted) setState(() => _isLoading = false);
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: const Text('E-posta Doğrulama')),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.mark_email_unread_outlined, size: 100, color: Colors.deepPurple),
                            const SizedBox(height: 24),
                            const Text('Hesabınızı Doğrulayın', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            Text('Lütfen ${widget.email} adresine gönderilen doğrulama bağlantısına tıklayın. E-postayı görmüyorsanız, spam klasörünüzü kontrol edin.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 32),
                            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _resendEmail, child: const Text('Doğrulama E-postasını Tekrar Gönder')),
                             const SizedBox(height: 16),
                             TextButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('Giriş Ekranına Dön'))
                        ],
                    ),
                ),
            ),
        );
    }
}

class SubmitQuestionScreen extends StatefulWidget {
  const SubmitQuestionScreen({super.key});

  @override
  State<SubmitQuestionScreen> createState() => _SubmitQuestionScreenState();
}

class _SubmitQuestionScreenState extends State<SubmitQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _optionEController = TextEditingController();
  
  int? _selectedCourseId;
  int? _selectedSubtopicId;
  String _correctOption = 'A';
  XFile? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    setState(() => _imageFile = image);
  }

  Future<void> _submit() async {
      if (!_formKey.currentState!.validate() || _selectedSubtopicId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun ve bir alt konu seçin.')));
          return;
      }
      setState(() => _isLoading = true);
      final fields = {'subtopic_id': _selectedSubtopicId.toString(), 'text': _textController.text, 'option_a': _optionAController.text, 'option_b': _optionBController.text, 'option_c': _optionCController.text, 'option_d': _optionDController.text, 'option_e': _optionEController.text, 'correct_option': _correctOption};
      try {
          final result = await ApiService.submitQuestion(fields, _imageFile);
          if (mounted) {
              if(!context.read<UserProvider>().isPremium) {
                context.read<AdService>().showInterstitialAd();
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
              Navigator.of(context).pop();
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      } finally {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Soru Gönder')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<List<dynamic>>(
                      future: ApiService.getCourses(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        return DropdownButtonFormField<int>(
                          value: _selectedCourseId,
                          hint: const Text("Ders Seçin"),
                          onChanged: (value) => setState(() { _selectedCourseId = value; _selectedSubtopicId = null; }),
                          items: snapshot.data!.map<DropdownMenuItem<int>>((course) => DropdownMenuItem<int>(value: course['id'], child: Text(course['name']))).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedCourseId != null)
                      FutureBuilder<List<dynamic>>(
                        future: ApiService.getSubtopics(_selectedCourseId!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Alt konular yükleniyor...');
                          return DropdownButtonFormField<int>(
                             value: _selectedSubtopicId,
                             hint: const Text("Alt Konu Seçin"),
                             onChanged: (value) => setState(() => _selectedSubtopicId = value),
                             items: snapshot.data!.map<DropdownMenuItem<int>>((subtopic) => DropdownMenuItem<int>(value: subtopic['id'], child: Text(subtopic['name']))).toList(),
                             validator: (v) => v == null ? 'Alt konu seçimi zorunludur' : null,
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(controller: _textController, decoration: const InputDecoration(labelText: 'Soru Metni'), maxLines: 5, validator: (v) => v!.isEmpty ? 'Soru metni boş olamaz' : null),
                    const SizedBox(height: 16),
                    TextFormField(controller: _optionAController, decoration: const InputDecoration(labelText: 'A Seçeneği'), validator: (v) => v!.isEmpty ? 'Boş olamaz' : null),
                    TextFormField(controller: _optionBController, decoration: const InputDecoration(labelText: 'B Seçeneği'), validator: (v) => v!.isEmpty ? 'Boş olamaz' : null),
                    TextFormField(controller: _optionCController, decoration: const InputDecoration(labelText: 'C Seçeneği'), validator: (v) => v!.isEmpty ? 'Boş olamaz' : null),
                    TextFormField(controller: _optionDController, decoration: const InputDecoration(labelText: 'D Seçeneği'), validator: (v) => v!.isEmpty ? 'Boş olamaz' : null),
                    TextFormField(controller: _optionEController, decoration: const InputDecoration(labelText: 'E Seçeneği'), validator: (v) => v!.isEmpty ? 'Boş olamaz' : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _correctOption,
                      decoration: const InputDecoration(labelText: 'Doğru Seçenek'),
                      items: ['A', 'B', 'C', 'D', 'E'].map((label) => DropdownMenuItem(child: Text(label), value: label)).toList(),
                      onChanged: (value) => setState(() => _correctOption = value!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: const Text('Resim Seç')),
                        const SizedBox(width: 10),
                        if (_imageFile != null) Expanded(child: Text(_imageFile!.name, overflow: TextOverflow.ellipsis))
                      ],
                    ),
                     const SizedBox(height: 24),
                     _isLoading ? const Center(child: CircularProgressIndicator()) : Center(child: ElevatedButton(onPressed: _submit, child: const Text('Onaya Gönder'))),
                  ],
                ),
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  XFile? _avatarFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = Provider.of<UserProvider>(context, listen: false).username;
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    setState(() => _avatarFile = image);
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
        final result = await ApiService.updateUserProfile(_usernameController.text, _avatarFile);
        if (mounted) {
            Provider.of<UserProvider>(context, listen: false).updateUserPartial(result['user']);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil başarıyla güncellendi."), backgroundColor: Colors.green));
            Navigator.of(context).pop(true);
        }
    } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
        if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profili Düzenle')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(radius: 60, backgroundImage: _avatarFile != null ? FileImage(File(_avatarFile!.path)) : CachedNetworkImageProvider(ApiService.getFullUrl(context.watch<UserProvider>().avatarUrl)) as ImageProvider),
                          Positioned(bottom: 0, right: 0, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.deepPurple), onPressed: _pickAvatar))
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Kullanıcı Adı'), validator: (value) => value!.isEmpty ? 'Kullanıcı adı boş olamaz' : null),
                    const SizedBox(height: 32),
                    _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _updateProfile, child: const Text('Değişiklikleri Kaydet'))
                  ],
                ),
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetRequest() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.requestPasswordReset(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Unuttum')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Kayıtlı e-posta adresinizi girerek şifre sıfırlama talimatlarını alabilirsiniz.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'E-posta Adresi'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _sendResetRequest, child: const Text('Sıfırlama Linki Gönder')),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  const FullScreenImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Container(
        color: Colors.black,
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String title;
  const PdfViewerScreen({super.key, required this.pdfUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: SfPdfViewer.network(
              pdfUrl,
              headers: {'Authorization': 'Bearer ${ApiService._token}'},
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class PublicProfileScreen extends StatefulWidget {
    final int userId;
    const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
    Map<String, dynamic>? _profileData;
    List<dynamic> _questions = [];
    int _currentPage = 1;
    bool _hasNextPage = true;
    bool _isLoading = false;
    final ScrollController _scrollController = ScrollController();

    @override
    void initState() {
        super.initState();
        _fetchProfileAndQuestions();
        _scrollController.addListener(() {
            if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasNextPage && !_isLoading) {
                _fetchProfileAndQuestions(page: _currentPage + 1);
            }
        });
    }

    @override
    void dispose() {
        _scrollController.dispose();
        super.dispose();
    }

    Future<void> _fetchProfileAndQuestions({int page = 1}) async {
        if (_isLoading) return;
        setState(() => _isLoading = true);
        try {
            final profileData = await ApiService.getUserProfile(widget.userId, page: page);
            if(mounted) {
              setState(() {
                  if (_profileData == null) {
                      _profileData = profileData;
                  }
                  final questionData = profileData['approved_questions'];
                  _questions.addAll(questionData['items']);
                  _currentPage = questionData['page'];
                  _hasNextPage = questionData['has_next'];
              });
            }
        } catch (e) {
            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Profil yüklenemedi: $e"), backgroundColor: Colors.red));
        } finally {
            if(mounted) setState(() => _isLoading = false);
        }
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text(_profileData?['username'] ?? 'Kullanıcı Profili'),
            ),
            body: Column(
              children: [
                Expanded(
                  child: _profileData == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                  CircleAvatar(
                                      radius: 50,
                                      backgroundImage: CachedNetworkImageProvider(ApiService.getFullUrl(_profileData!['avatar_url'])),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(_profileData!['username'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('Puan: ${_profileData!['score']}', style: TextStyle(fontSize: 20, color: Colors.grey[700])),
                                  
                                  RankAndBadges(
                                    rank: _profileData!['rank'],
                                    totalUsers: _profileData!['total_users'],
                                    badges: _profileData!['badges'] as List<dynamic>? ?? [],
                                  ),
                
                                  const SizedBox(height: 24),
                                  const Text("Onaylanan Soruları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                   ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _questions.length + (_hasNextPage ? 1 : 0),
                                      itemBuilder: (context, index) {
                                          if(index == _questions.length && _hasNextPage) {
                                              return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                                          }
                                          final q = _questions[index];
                                          return Card(
                                              child: ListTile(
                                                  title: Text(q['text_preview'], maxLines: 1, overflow: TextOverflow.ellipsis), 
                                                  subtitle: Text(q['course_name'] ?? ''),
                                                  onTap: () {
                                                      final linkId = q['link_id'];
                                                      if (linkId != null) {
                                                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => SingleQuestionViewer(linkId: linkId)));
                                                      }
                                                  },
                                              ),
                                          );
                                      }
                                   )
                              ],
                          ),
                      ),
                ),
                const BannerAdWidget(),
              ],
            ),
        );
    }
}

class SingleQuestionViewer extends StatelessWidget {
    final String linkId;
    const SingleQuestionViewer({super.key, required this.linkId});

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: const Text("Soru Detayı")),
            body: Column(
              children: [
                Expanded(
                  child: FutureBuilder<Map<String, dynamic>>(
                      future: ApiService.getQuestionByLinkId(linkId),
                      builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                              return Center(child: Text("Soru yüklenemedi: ${snapshot.error}"));
                          }
                          if (!snapshot.hasData) {
                              return const Center(child: Text("Soru bulunamadı."));
                          }
                          return QuestionCard(
                            questionData: snapshot.data!,
                            courseId: snapshot.data!['course_id'] ?? 0,
                            courseName: snapshot.data!['course_name'] ?? '',
                          );
                      },
                  ),
                ),
                const BannerAdWidget(),
              ],
            ),
        );
    }
}

class RankAndBadges extends StatelessWidget {
  final int? rank;
  final int? totalUsers;
  final List<dynamic> badges;

  const RankAndBadges({
    super.key,
    required this.rank,
    required this.totalUsers,
    required this.badges,
  });

  Widget _buildBadgeIcon(String badgeName) {
    IconData badgeIcon = Icons.shield;
    Color badgeColor = Colors.grey;
    String tooltip = "Rozet";

    switch (badgeName.toLowerCase()) {
      case 'gold':
        badgeIcon = Icons.emoji_events;
        badgeColor = Colors.amber;
        tooltip = "Altın Rozet (İlk 100)";
        break;
      case 'silver':
        badgeIcon = Icons.emoji_events;
        badgeColor = Colors.grey.shade400;
        tooltip = "Gümüş Rozet (İlk 1000)";
        break;
      case 'bronze':
        badgeIcon = Icons.emoji_events;
        badgeColor = Colors.brown.shade400;
        tooltip = "Bronz Rozet (İlk 10000)";
        break;
    }
    return Tooltip(message: tooltip, child: Icon(badgeIcon, color: badgeColor, size: 30));
  }

  @override
  Widget build(BuildContext context) {
    if (rank == null || totalUsers == null) {
      return const SizedBox.shrink(); 
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Text(
            'Sıralama: $rank / $totalUsers',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (badges.isNotEmpty) const SizedBox(height: 8),
          if (badges.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: badges.map((badge) => _buildBadgeIcon(badge.toString())).toList(),
            ),
        ],
      ),
    );
  }
}