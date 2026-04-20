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
        colorSchemeSeed: const Color(0xFF00C3FF),
        scaffoldBackgroundColor: const Color(0xFF0A0D18),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const StudyTimerPage(),
    );
  }
}

// ==========================================
// 2. 全履歴画面：HistoryPage (三点リーダー削除機能付き)
// ==========================================
class HistoryPage extends StatefulWidget {
  final List<StudyLog> allLogs;
  final Map<String, IconData> subjectIcons;

  const HistoryPage({super.key, required this.allLogs, required this.subjectIcons});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int get totalMinutesAll => widget.allLogs.fold(0, (sum, log) => sum + log.minutes);

  Map<String, List<StudyLog>> get groupedLogs {
    Map<String, List<StudyLog>> groups = {};
    for (var log in widget.allLogs) {
      String dateKey = log.formattedFullDate;
      if (groups[dateKey] == null) groups[dateKey] = [];
      groups[dateKey]!.add(log);
    }
    return groups;
  }

  // 特定のログを削除するメソッド
  Future<void> _deleteLog(StudyLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('study_logs') ?? [];

    // 開始時間をキーにしてSharedPreferencesから削除
    stored.removeWhere((item) {
      final map = jsonDecode(item);
      return map['startTime'] == log.startTime.toIso8601String();
    });

    await prefs.setStringList('study_logs', stored);

    // メモリ上のリストも更新してUIを再描画
    setState(() {
      widget.allLogs.remove(log);
    });
  }

  // 削除確認ダイアログ
  void _showDeleteConfirmDialog(StudyLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B2339),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("ログの削除", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: const Text("この学習記録を削除しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("キャンセル", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              _deleteLog(log);
              Navigator.pop(context);
            },
            child: const Text("削除", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupedLogs;

    return Scaffold(
      appBar: AppBar(
        title: Text("ALL HISTORY", style: GoogleFonts.montserrat(letterSpacing: 1, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0A0D18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0D18), Color(0xFF1B2339)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _buildTotalStatsCard(),
            Expanded(
              child: widget.allLogs.isEmpty
                  ? const Center(child: Text("まだ履歴がありません"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: groups.keys.length,
                      itemBuilder: (_, index) {
                        String date = groups.keys.elementAt(index);
                        List<StudyLog> logsInDate = groups[date]!;
                        int dailyTotal = logsInDate.fold(0, (sum, log) => sum + log.minutes);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                              child: Row(
                                children: [
                                  Text(date, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF00C3FF), fontSize: 13)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C3FF).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF00C3FF).withOpacity(0.3), width: 0.5),
                                    ),
                                    child: Text("${dailyTotal} 分", style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF00C3FF), fontWeight: FontWeight.bold)),
                                  ),
                                  const Expanded(child: Divider(indent: 12, color: Colors.white10)),
                                ],
                              ),
                            ),
                            ...logsInDate.map((log) => _buildDetailCard(log)).toList(),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStatsCard() {
    Map<String, int> stats = {};
    for (var log in widget.allLogs) {
      stats[log.subject] = (stats[log.subject] ?? 0) + log.minutes;
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00C3FF).withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00C3FF).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text("TOTAL STUDY TIME", style: GoogleFonts.montserrat(fontSize: 11, letterSpacing: 2, color: const Color(0xFF00C3FF), fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text("${(totalMinutesAll ~/ 60)}h ${(totalMinutesAll % 60)}m", style: GoogleFonts.jetBrainsMono(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                const Divider(height: 28, color: Colors.white12),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: stats.entries.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: Text("${e.key}: ${e.value}分", style: GoogleFonts.inter(fontSize: 10, color: Colors.white70)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(StudyLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withOpacity(0.04),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(widget.subjectIcons[log.subject] ?? Icons.book, color: const Color(0xFF00C3FF), size: 18),
        title: Text(log.memo.isEmpty ? '（メモなし）' : log.memo, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
        subtitle: Text('${log.subject} • ${log.minutes}分 / ${log.formattedTimeRange}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
          color: const Color(0xFF1B2339),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
          onSelected: (value) {
            if (value == 'delete') _showDeleteConfirmDialog(log);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text("削除", style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
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
    '情報': Icons.computer_rounded,
    '数学': Icons.calculate_rounded,
    '英語': Icons.language_rounded,
    'その他': Icons.more_horiz_rounded,
  };

  double get progress => (elapsedSeconds / goalSeconds).clamp(0.0, 1.0);

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
          gradient: LinearGradient(colors: [Color(0xFF0A0D18), Color(0xFF1B2339)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 12),
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
                              const SizedBox(width: 28),
                              Column(
                                children: [
                                  Text('TIMER', style: GoogleFonts.montserrat(letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          buildPlayerControls(),
                          const SizedBox(height: 5),
                          Slider(
                            value: volume, 
                            activeColor: const Color(0xFF00C3FF),
                            inactiveColor: Colors.white12,
                            onChanged: (v) { setState(() => volume = v); player.setVolume(v); }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: contentWidth,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: subjectIcons.entries.map((e) => ChoiceChip(
                      label: Text(e.key), 
                      avatar: Icon(e.value, size: 14, color: selectedSubject == e.key ? Colors.black87 : const Color(0xFF00C3FF)),
                      selected: selectedSubject == e.key,
                      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: selectedSubject == e.key ? Colors.black87 : Colors.white),
                      selectedColor: const Color(0xFF00C3FF),
                      backgroundColor: Colors.white.withOpacity(0.06),
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20), 
                        side: BorderSide(color: selectedSubject == e.key ? Colors.transparent : Colors.white12, width: 0.5),
                      ),
                      onSelected: (_) => setState(() => selectedSubject = e.key),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: contentWidth,
                  child: TextField(
                    controller: memoController, 
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '何をする？', 
                      hintStyle: GoogleFonts.inter(color: Colors.white38),
                      filled: true, 
                      fillColor: Colors.white.withOpacity(0.06), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12, width: 0.5)),
                    )
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: contentWidth, 
                  child: ElevatedButton.icon(
                    onPressed: saveLog, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C3FF),
                      foregroundColor: Colors.black87,
                      minimumSize: const Size.fromHeight(50),
                      elevation: 5,
                      shadowColor: const Color(0xFF00C3FF).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text("学習を記録する", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: contentWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("TODAY'S LOG", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1)),
                          const SizedBox(height: 2),
                          Text("今日の合計: $totalMinutesToday 分", style: GoogleFonts.inter(color: const Color(0xFF00C3FF), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      _buildHistoryButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SizedBox(
                    width: contentWidth,
                    child: todayLogs.isEmpty 
                      ? const Center(child: Text("今日の履歴はまだありません", style: TextStyle(color: Colors.white24, fontSize: 13)))
                      : ListView.builder(
                          itemCount: todayLogs.length,
                          itemBuilder: (_, i) {
                            final log = todayLogs[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.white.withOpacity(0.04),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14), 
                                side: BorderSide(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(subjectIcons[log.subject] ?? Icons.book, color: const Color(0xFF00C3FF), size: 18),
                                title: Text(log.memo.isEmpty ? '（メモなし）' : log.memo, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
                                subtitle: Text('${log.subject} • ${log.minutes}分 / ${log.formattedTimeRange}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
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

  Widget _buildHistoryButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00C3FF).withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00C3FF).withOpacity(0.12), blurRadius: 6, spreadRadius: 0),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          // 履歴画面へ遷移し、戻ってきたら再読み込み
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HistoryPage(
                allLogs: List.from(logs), 
                subjectIcons: subjectIcons,
              ),
            ),
          );
          loadLogs();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.history_toggle_off_rounded, size: 14, color: Color(0xFF00C3FF)),
              const SizedBox(width: 6),
              Text("ALL HISTORY", style: GoogleFonts.montserrat(color: const Color(0xFF00C3FF), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCDWithProgress() {
    return SizedBox(
      width: 110, height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress, 
            strokeWidth: 3, 
            backgroundColor: Colors.white10,
            color: const Color(0xFF00C3FF).withOpacity(0.5),
          ),
          if(isRunning) Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C3FF).withOpacity(0.15), 
                  blurRadius: 10, 
                  spreadRadius: 1,
                ),
              ]
            ),
          ),
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    const Color(0xFF00C3FF).withOpacity(0.05), 
                    const Color(0xFF00C3FF).withOpacity(0.3), 
                    const Color(0xFF00C3FF).withOpacity(0.05)
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: [
                  const BoxShadow(color: Colors.black54, blurRadius: 3),
                ]
              ),
              child: ClipOval(child: Image.asset('assets/$currentImage', width: 42, height: 42, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white24, size: 20))),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlayerControls() {
    return Column(
      children: [
        Text(currentTrack, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 22), color: Colors.white70, onPressed: () { setState(() => selectedTrackIndex = (selectedTrackIndex - 1 + tracks.length) % tracks.length); if (isRunning) playStudyBgm(); }),
            IconButton(icon: Icon(isRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded, size: 48, color: const Color(0xFF00C3FF)), onPressed: isRunning ? stopTimer : startTimer),
            IconButton(icon: const Icon(Icons.skip_next_rounded, size: 22), color: Colors.white70, onPressed: () { setState(() => selectedTrackIndex = (selectedTrackIndex + 1) % tracks.length); if (isRunning) playStudyBgm(); }),
          ],
        ),
      ],
    );
  }

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
            ),
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}