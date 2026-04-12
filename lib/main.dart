import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StudyTimerPage(),
    );
  }
}

class StudyTimerPage extends StatefulWidget {
  const StudyTimerPage({super.key});

  @override
  State<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends State<StudyTimerPage> {
  int elapsedSeconds = 0;
  Timer? timer;
  bool isRunning = false;

  final AudioPlayer _player = AudioPlayer();

  String selectedSubject = '情報';
  final TextEditingController memoController = TextEditingController();

  List<StudyLog> logs = [];

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  @override
  void dispose() {
    timer?.cancel();
    _player.dispose();
    memoController.dispose();
    super.dispose();
  }

  Future<void> playBgm() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('bgm.mp3'));
  }

  Future<void> stopBgm() async {
    await _player.stop();
  }

  void startTimer() {
    timer?.cancel();

    setState(() {
      isRunning = true;
    });

    playBgm();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        elapsedSeconds++;
      });
    });
  }

  void stopTimer() {
    timer?.cancel();
    stopBgm();

    setState(() {
      isRunning = false;
    });
  }

  Future<void> saveLog() async {
    stopBgm();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学習タイマー')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${elapsedSeconds ~/ 60} 分 ${elapsedSeconds % 60} 秒',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 10),

            DropdownButton<String>(
              value: selectedSubject,
              items: ['情報', '数学', '英語', 'その他']
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value!;
                });
              },
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? null : startTimer,
                  child: const Text('スタート'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: isRunning ? stopTimer : null,
                  child: const Text('ストップ'),
                ),
              ],
            ),

            TextField(
              controller: memoController,
              decoration: const InputDecoration(
                labelText: '学習内容（メモ）',
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: saveLog,
              child: const Text('保存'),
            ),

            const SizedBox(height: 20),

            const Text(
              '学習履歴',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(
                        log.memo.isNotEmpty ? log.memo : '（メモなし）',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${log.subject} / ${log.minutes}分'),
                      trailing:
                          Text('${log.date.month}/${log.date.day}'),
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