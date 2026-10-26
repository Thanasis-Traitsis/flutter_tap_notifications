import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../articles/article.dart';
import '../articles/article_repository.dart';
import '../navigation/app_routes.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key, required this.repository});

  final ArticleRepository repository;

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late final Future<List<Article>> _articles = widget.repository.getAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Articles')),
      body: FutureBuilder<List<Article>>(
        future: _articles,
        builder: (context, snapshot) {
          final articles = snapshot.data;
          if (articles == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              for (final article in articles)
                ListTile(
                  title: Text(article.title),
                  onTap: () =>
                      context.push(AppRoutes.articleDetails, extra: article),
                ),
            ],
          );
        },
      ),
    );
  }
}
