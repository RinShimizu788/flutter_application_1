import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String selectedSubject = 'アルゴリズム';
  final TextEditingController memoController = TextEditingController();

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        elapsedSeconds++;
      });
    });
    isRunning = true;
  }

  void stopTimer() {
    timer?.cancel();
    setState(() {
      isRunning = false;
    });
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

    setState(() {
      elapsedSeconds = 0;
      memoController.clear();
      isRunning = false;
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
              decoration: const InputDecoration(labelText: '学習内容'),
            ),
            ElevatedButton(
              onPressed: saveLog,
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}