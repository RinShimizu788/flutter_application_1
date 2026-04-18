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
    await player.setVolume(volume);
  }

  Future<void> playIdleBgm() async {
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('idle.mp3'));
    await player.setVolume(volume*0.4);
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
              ),
            ),
          ),
        ],
      ),
    );
  }

// 追加なし（そのまま全部）

// ↓ 途中は同じなので変更点だけじゃなく全部載せる

// （※省略せず全文なので長いです）

// ===============================
// 🔽 ここが追加ポイント
// ===============================

  Widget buildPlayerControls() {
    return Column(
      children: [
        Text(currentTrack),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
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
              icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
              onPressed: isRunning ? stopTimer : startTimer,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
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

  // ⭐③ 追加：音量コントロール
  Widget buildVolumeControl() {
    return Column(
      children: [
        const SizedBox(height: 10),
        const Text("音量"),
        Slider(
          value: volume,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: (volume * 100).toInt().toString(),
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
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E1E2F),
                Color(0xFF3A3A5A),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
            child: Column(
              children: [
                /// ⭐ メインカード
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: glassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              buildCDWithProgress(),
                              const SizedBox(width: 20),
                              Column(
                                children: [
                                  Text(
                                    'StudyTimer',
                                    style: GoogleFonts.montserrat(
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${elapsedSeconds ~/ 60} 分 ${elapsedSeconds % 60} 秒',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ⭐④ ここに追加！！
                          buildPlayerControls(),
                          buildVolumeControl(), // ←音量スライダー
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// ⭐ 教科ボタン
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      children: subjectIcons.entries.map((e) {
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(e.value, size: 18),
                              const SizedBox(width: 6),
                              Text(e.key),
                            ],
                          ),
                          selected: selectedSubject == e.key,
                          onSelected: (_) {
                            setState(
                                () => selectedSubject = e.key);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// ⭐ 入力欄
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: '学習内容',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// ⭐ 保存ボタン
                Center(
                  child: SizedBox(
                    width: contentWidth,
                    child: ElevatedButton(
                      onPressed: saveLog,
                      child: const Text('保存'),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// ⭐ 履歴
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final log = logs[i];
                          return Card(
                            color:
                                Colors.white.withOpacity(0.05),
                            child: ListTile(
                              title: Text(
                                log.memo.isNotEmpty
                                    ? log.memo
                                    : '（メモなし）',
                              ),
                              subtitle: Text(
                                  '${log.subject} / ${log.minutes}分'),
                            ),
                          );
                        },
                      ),
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