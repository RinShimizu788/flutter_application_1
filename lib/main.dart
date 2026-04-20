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

class StudyLog {
  final String subject;
  final int minutes;
  final String memo;
  final DateTime date;

  StudyLog({
    required this.subject,
    required this.minutes,
    required this.memo,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'minutes': minutes,
      'memo': memo,
      'date': date.toIso8601String(),
    };
  }

  // ⭐ Null安全に対応させたファクトリ
  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      subject: map['subject']?.toString() ?? '情報',
      minutes: map['minutes'] is int ? map['minutes'] : 0,
      memo: map['memo']?.toString() ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
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

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage>
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _initApp(); // 初期化処理をまとめる

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _rotation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  // ⭐ データ読み込みと音楽の初期設定
  Future<void> _initApp() async {
    // 【重要】もし履歴が壊れていたら下の行のコメントアウトを外して1度だけ実行してください
    // final prefs = await SharedPreferences.getInstance(); await prefs.clear();
    
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

  // ⭐ 修正版：保存ロジック
  Future<void> saveLog() async {
    // 1分未満でもテスト用に保存したい場合はここを 0 にしてください
    final minutes = elapsedSeconds ~/ 60;
    if (elapsedSeconds < 1) return; 

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('study_logs') ?? [];

      final log = StudyLog(
        subject: selectedSubject,
        minutes: minutes,
        memo: memoController.text,
        date: DateTime.now(),
      );

      stored.add(jsonEncode(log.toMap()));
      await prefs.setStringList('study_logs', stored);

      // 保存後に再読み込み
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

  // ⭐ 修正版：読み込みロジック（エラー行をスキップ）
  Future<void> loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('study_logs') ?? [];

      List<StudyLog> loaded = [];
      for (var item in stored) {
        try {
          final decoded = jsonDecode(item);
          loaded.add(StudyLog.fromMap(decoded));
        } catch (e) {
          debugPrint("Failed to decode log: $e");
        }
      }

      setState(() {
        logs = loaded.reversed.toList();
      });
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  Widget buildCDWithProgress() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isRunning
                      ? [Colors.black, Colors.blueGrey, Colors.black]
                      : [Colors.grey, Colors.black26],
                ),
                boxShadow: isRunning
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.6),
                          blurRadius: 20,
                        )
                      ]
                    : [],
              ),
            ),
          ),
          RotationTransition(
            turns: _rotation,
            child: ClipOval(
              child: Image.asset(
                'assets/$currentImage',
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlayerControls() {
    return Column(
      children: [
        Text(currentTrack, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                setState(() {
                  selectedTrackIndex = (selectedTrackIndex - 1 + tracks.length) % tracks.length;
                });
                if (isRunning) playStudyBgm();
              },
            ),
            IconButton(
              icon: Icon(isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 40),
              onPressed: isRunning ? stopTimer : startTimer,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                setState(() {
                  selectedTrackIndex = (selectedTrackIndex + 1) % tracks.length;
                });
                if (isRunning) playStudyBgm();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget buildVolumeControl() {
    return Column(
      children: [
        const Text("Volume", style: TextStyle(fontSize: 12)),
        Slider(
          value: volume,
          onChanged: (value) async {
            setState(() => volume = value);
            await player.setVolume(volume);
          },
        ),
      ],
    );
  }

  Widget glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double contentWidth = 410;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1E2F), Color(0xFF3A3A5A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
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
                                    const SizedBox(height: 8),
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
                            buildVolumeControl(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: contentWidth,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: subjectIcons.entries.map((e) {
                        return ChoiceChip(
                          label: Text(e.key),
                          avatar: Icon(e.value, size: 16),
                          selected: selectedSubject == e.key,
                          onSelected: (_) => setState(() => selectedSubject = e.key),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: contentWidth,
                    child: TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        hintText: '何をする？',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: contentWidth,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: saveLog,
                      icon: const Icon(Icons.save),
                      label: const Text("学習を記録する"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("HISTORY", style: TextStyle(fontSize: 12, letterSpacing: 1.5)),
                  Expanded(
                    child: SizedBox(
                      width: contentWidth,
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white.withOpacity(0.05),
                            child: ListTile(
                              leading: Icon(subjectIcons[log.subject] ?? Icons.book),
                              title: Text(log.memo.isEmpty ? '（メモなし）' : log.memo),
                              subtitle: Text('${log.subject} • ${log.minutes}分'),
                              trailing: Text('${log.date.month}/${log.date.day}', style: const TextStyle(fontSize: 10)),
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
      ),
    );
  }
}