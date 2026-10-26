import 'package:flutter/material.dart';

import '../articles/article.dart';

class ArticleDetailsScreen extends StatelessWidget {
  const ArticleDetailsScreen({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(article.title, style: Theme.of(context).textTheme.titleLarge),
            Text(article.body),
          ],
        ),
      ),
    );
  }
}
