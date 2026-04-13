import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
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

  factory StudyLog.fromMap(Map<String, dynamic> map) {
    return StudyLog(
      subject: map['subject'],
      minutes: map['minutes'],
      memo: map['memo'],
      date: DateTime.parse(map['date']),
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

  double get progress =>
      (elapsedSeconds / goalSeconds).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    loadLogs();
    playIdleBgm();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _rotation = Tween<double>(begin: 0, end: 1).animate(_controller);
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
  }

  Future<void> playIdleBgm() async {
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('idle.mp3'));
    await player.setVolume(0.3);
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
    final minutes = elapsedSeconds ~/ 60;
    if (minutes == 0) return;

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

    await loadLogs();

    setState(() {
      elapsedSeconds = 0;
      memoController.clear();
      isRunning = false;
    });

    timer?.cancel();
    playIdleBgm();
    _controller.stop();
  }

  Future<void> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('study_logs') ?? [];

    setState(() {
      logs = stored
          .map((e) => StudyLog.fromMap(jsonDecode(e)))
          .toList()
          .reversed
          .toList();
    });
  }

  /// 💿 CD（中央に画像）
  Widget buildCDWithProgress() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// 進捗リング
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: Colors.grey.shade300,
          ),

          /// 外側CD
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isRunning
                      ? [Colors.black, Colors.blueGrey, Colors.black]
                      : [Colors.grey, Colors.black26],
                ),
              ),
            ),
          ),

          /// 中央画像（ジャケット）
          RotationTransition(
            turns: _rotation,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/$currentImage',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎵 プレイヤー
  Widget buildPlayerControls() {
    return Column(
      children: [
        Text(
          currentTrack,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 36),
              onPressed: () {
                setState(() {
                  selectedTrackIndex =
                      (selectedTrackIndex - 1 + tracks.length) %
                          tracks.length;
                });
                if (isRunning) playStudyBgm();
              },
            ),

            IconButton(
              icon: Icon(
                isRunning ? Icons.pause : Icons.play_arrow,
                size: 40,
              ),
              onPressed: isRunning ? stopTimer : startTimer,
            ),

            IconButton(
              icon: const Icon(Icons.skip_next, size: 36),
              onPressed: () {
                setState(() {
                  selectedTrackIndex =
                      (selectedTrackIndex + 1) % tracks.length;
                });
                if (isRunning) playStudyBgm();
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            /// タイマー（そのまま）
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 32,
                ),
                child: Column(
                  children: [
                    Text(
                      'StudyTimer',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${elapsedSeconds ~/ 60} 分 ${elapsedSeconds % 60} 秒',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            buildCDWithProgress(),

            const SizedBox(height: 20),

            buildPlayerControls(),

            const SizedBox(height: 20),

            /// 教科
            Wrap(
              spacing: 10,
              children: subjectIcons.entries.map((e) {
                return ChoiceChip(
                  label: Text(e.key),
                  selected: selectedSubject == e.key,
                  onSelected: (_) {
                    setState(() => selectedSubject = e.key);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: memoController,
              decoration: const InputDecoration(
                labelText: '学習内容',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: saveLog,
              child: const Text('保存'),
            ),

            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  return ListTile(
                    title: Text(
                      log.memo.isNotEmpty ? log.memo : '（メモなし）',
                    ),
                    subtitle:
                        Text('${log.subject} / ${log.minutes}分'),
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