import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

// ==========================================
// 1. データモデル：StudyLog
// ==========================================
class StudyLog {
  final String subject;
  final int minutes;
  final String memo;
  final DateTime startTime;
  final DateTime endTime;

  StudyLog({
    required this.subject,
    required this.minutes,
    required this.memo,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'minutes': minutes,
      'memo': memo,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }

  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      subject: map['subject']?.toString() ?? '情報',
      minutes: map['minutes'] is int ? map['minutes'] : 0,
      memo: map['memo']?.toString() ?? '',
      startTime: map['startTime'] != null ? DateTime.parse(map['startTime']) : DateTime.now(),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : DateTime.now(),
    );
  }

  String get formattedFullDate {
    final weekDays = ["日", "月", "火", "水", "木", "金", "土"];
    final w = weekDays[startTime.weekday % 7];
    return "${startTime.year}/${startTime.month}/${startTime.day}($w)";
  }

  String get formattedTimeRange {
    String hourS = startTime.hour.toString().padLeft(2, '0');
    String minS = startTime.minute.toString().padLeft(2, '0');
    String hourE = endTime.hour.toString().padLeft(2, '0');
    String minE = endTime.minute.toString().padLeft(2, '0');
    return "$hourS:$minS 〜 $hourE:$minE";
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const StudyTimerPage(),
    );
  }
}

// ==========================================
// 2. 全履歴画面：HistoryPage（統計ダッシュボード付き）
// ==========================================
class HistoryPage extends StatelessWidget {
  final List<StudyLog> allLogs;
  final Map<String, IconData> subjectIcons;

  const HistoryPage({super.key, required this.allLogs, required this.subjectIcons});

  int get totalMinutesAll => allLogs.fold(0, (sum, log) => sum + log.minutes);

  Map<String, int> get subjectStats {
    Map<String, int> stats = {};
    for (var log in allLogs) {
      stats[log.subject] = (stats[log.subject] ?? 0) + log.minutes;
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final stats = subjectStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text("すべての学習履歴"),
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF3A3A5A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // 累計統計カード
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text("TOTAL STUDY TIME",
                            style: TextStyle(fontSize: 12, letterSpacing: 1.5, color: Colors.blueAccent)),
                        const SizedBox(height: 8),
                        Text(
                          "${(totalMinutesAll ~/ 60)}h ${(totalMinutesAll % 60)}m",
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Divider(height: 30, color: Colors.white10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: stats.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${e.key}: ${e.value}分",
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("詳細ログ一覧", style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            // リスト表示
            Expanded(
              child: allLogs.isEmpty
                  ? const Center(child: Text("履歴がありません"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: allLogs.length,
                      itemBuilder: (_, i) {
                        final log = allLogs[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(subjectIcons[log.subject] ?? Icons.book, color: Colors.blueAccent),
                            title: Text(log.memo.isEmpty ? '（メモなし）' : log.memo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${log.subject} • ${log.minutes}分\n${log.formattedFullDate} ${log.formattedTimeRange}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. メイン画面：StudyTimerPage
// ==========================================
class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> with SingleTickerProviderStateMixin {
  double volume = 0.8;
  int elapsedSeconds = 0;
  int goalSeconds = 1500;
  Timer? timer;
  bool isRunning = false;
  String selectedSubject = '情報';

  final List<Map<String, String>> tracks = [
    {'name': 'again', 'file': 'bgm1.mp3', 'image': 'cover1.jpg'},
    {'name': 'HANABI', 'file': 'bgm2.m4a', 'image': 'cover2.jpg'},
  ];

  int selectedTrackIndex = 0;
  String get currentTrack => tracks[selectedTrackIndex]['name']!;
  String get currentFile => tracks[selectedTrackIndex]['file']!;
  String get currentImage => tracks[selectedTrackIndex]['image']!;

  final TextEditingController memoController = TextEditingController();
  List<StudyLog> logs = [];
  final AudioPlayer player = AudioPlayer();
  late AnimationController _controller;
  late Animation<double> _rotation;

  final Map<String, IconData> subjectIcons = {
    '情報': Icons.computer,
    '数学': Icons.calculate,
    '英語': Icons.language,
    'その他': Icons.more_horiz,
  };

  double get progress => (elapsedSeconds / goalSeconds).clamp(0.0, 1.0);

  // 今日のログ・合計時間
  List<StudyLog> get todayLogs {
    final now = DateTime.now();
    return logs.where((log) {
      return log.startTime.year == now.year &&
             log.startTime.month == now.month &&
             log.startTime.day == now.day;
    }).toList();
  }
  int get totalMinutesToday => todayLogs.fold(0, (sum, log) => sum + log.minutes);

  @override
  void initState() {
    super.initState();
    _initApp();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _rotation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  Future<void> _initApp() async {
    await loadLogs();
    await playIdleBgm();
  }

  @override
  void dispose() {
    timer?.cancel();
    memoController.dispose();
    player.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> playStudyBgm() async {
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource(currentFile));
    await player.setVolume(volume);
  }

  Future<void> playIdleBgm() async {
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    try {
      await player.play(AssetSource('idle.mp3'));
      await player.setVolume(volume * 0.4);
    } catch (e) {
      debugPrint("Idle BGM error: $e");
    }
  }

  void startTimer() {
    timer?.cancel();
    setState(() => isRunning = true);
    playStudyBgm();
    _controller.repeat();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsedSeconds++);
    });
  }

  void stopTimer() {
    timer?.cancel();
    setState(() => isRunning = false);
    playIdleBgm();
    _controller.stop();
  }

  Future<void> saveLog() async {
    if (elapsedSeconds < 1) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('study_logs') ?? [];
      final now = DateTime.now();
      final start = now.subtract(Duration(seconds: elapsedSeconds));

      final log = StudyLog(
        subject: selectedSubject,
        minutes: elapsedSeconds ~/ 60,
        memo: memoController.text,
        startTime: start,
        endTime: now,
      );

      stored.add(jsonEncode(log.toMap()));
      await prefs.setStringList('study_logs', stored);
      await loadLogs();

      setState(() {
        elapsedSeconds = 0;
        memoController.clear();
        isRunning = false;
      });
      timer?.cancel();
      playIdleBgm();
      _controller.stop();
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('study_logs') ?? [];
      List<StudyLog> loaded = [];
      for (var item in stored) {
        try {
          loaded.add(StudyLog.fromMap(jsonDecode(item)));
        } catch (e) {
          debugPrint("Failed to decode log: $e");
        }
      }
      setState(() => logs = loaded.reversed.toList());
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const double contentWidth = 410;
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1E1E2F), Color(0xFF3A3A5A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // タイマーセクション
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: glassCard(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              buildCDWithProgress(),
                              const SizedBox(width: 24),
                              Column(
                                children: [
                                  Text('TIMER', style: GoogleFonts.montserrat(letterSpacing: 2)),
                                  Text(
                                    '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          buildPlayerControls(),
                          Slider(value: volume, onChanged: (v) { setState(() => volume = v); player.setVolume(v); }),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // 入力セクション
                SizedBox(
                  width: contentWidth,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: subjectIcons.entries.map((e) => ChoiceChip(
                      label: Text(e.key), avatar: Icon(e.value, size: 16),
                      selected: selectedSubject == e.key,
                      onSelected: (_) => setState(() => selectedSubject = e.key),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: contentWidth,
                  child: TextField(controller: memoController, decoration: const InputDecoration(hintText: '何をする？', filled: true, fillColor: Colors.white10, border: OutlineInputBorder())),
                ),
                const SizedBox(height: 10),
                SizedBox(width: contentWidth, child: ElevatedButton(onPressed: saveLog, child: const Text("学習を記録する"))),
                const SizedBox(height: 25),

                // 今日のみの履歴見出し
                SizedBox(
                  width: contentWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("TODAY'S LOG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("今日の合計: $totalMinutesToday 分", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      // ネオンデザインの「すべて表示」ボタン
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(color: Colors.blueAccent.withOpacity(0.1), blurRadius: 4, spreadRadius: 1),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryPage(allLogs: logs, subjectIcons: subjectIcons))),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 16, color: Colors.blueAccent),
                                SizedBox(width: 4),
                                Text("すべて表示", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 今日のリスト
                Expanded(
                  child: SizedBox(
                    width: contentWidth,
                    child: todayLogs.isEmpty 
                      ? const Center(child: Text("今日の履歴はまだありません", style: TextStyle(color: Colors.white24)))
                      : ListView.builder(
                          itemCount: todayLogs.length,
                          itemBuilder: (_, i) {
                            final log = todayLogs[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.white.withOpacity(0.05),
                              child: ListTile(
                                leading: Icon(subjectIcons[log.subject] ?? Icons.book, color: Colors.blueAccent),
                                title: Text(log.memo.isEmpty ? '（メモなし）' : log.memo),
                                subtitle: Text('${log.subject} • ${log.minutes}分 / ${log.formattedTimeRange}'),
                              ),
                            );
                          },
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

  // --- ヘルパーWidget群 ---
  Widget buildCDWithProgress() {
    return SizedBox(
      width: 120, height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: progress, strokeWidth: 3, backgroundColor: Colors.white10),
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: [Colors.blueAccent.withOpacity(0.1), Colors.blueAccent, Colors.blueAccent.withOpacity(0.1)]),
              ),
            ),
          ),
          RotationTransition(
            turns: _rotation,
            child: ClipOval(child: Image.asset('assets/$currentImage', width: 45, height: 45, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note))),
          ),
        ],
      ),
    );
  }

  Widget buildPlayerControls() {
    return Column(
      children: [
        Text(currentTrack, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.skip_previous), onPressed: () { setState(() => selectedTrackIndex = (selectedTrackIndex - 1 + tracks.length) % tracks.length); if (isRunning) playStudyBgm(); }),
            IconButton(icon: Icon(isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 45, color: Colors.blueAccent), onPressed: isRunning ? stopTimer : startTimer),
            IconButton(icon: const Icon(Icons.skip_next), onPressed: () { setState(() => selectedTrackIndex = (selectedTrackIndex + 1) % tracks.length); if (isRunning) playStudyBgm(); }),
          ],
        ),
      ],
    );
  }

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: child,
        ),
      ),
    );
  }
}