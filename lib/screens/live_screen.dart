import 'package:flutter/material.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(Icons.graphic_eq, size: 64, color: Colors.red),
            Text('On air now: The Morning Show'),
          ],
        ),
      ),
    );
  }
}
