import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  static const _shows = [
    ('08:00', 'The Morning Show'),
    ('12:00', 'Midday Sports Talk'),
    ('18:00', 'Match Day Live'),
    ('22:00', 'Late Night Music'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: ListView(
        children: [
          for (final (time, title) in _shows)
            ListTile(leading: Text(time), title: Text(title)),
        ],
      ),
    );
  }
}
