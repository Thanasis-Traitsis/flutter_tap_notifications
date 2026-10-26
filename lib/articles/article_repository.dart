import 'article.dart';

/// A fake backend. Swap it for your real API; the tap logic doesn't change.
class ArticleRepository {
  ArticleRepository({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;

  static const _articles = {
    '1': Article(
      id: '1',
      title: 'Tonight: the derby, live from the stadium',
      body: 'Kick-off coverage starts one hour before the match.',
    ),
    '2': Article(
      id: '2',
      title: 'New morning show starts next week',
      body: 'Two new voices, three hours, every weekday.',
    ),
    '3': Article(
      id: '3',
      title: 'Behind the mic: a day at the studio',
      body: 'What really happens before the red light turns on.',
    ),
  };

  Future<List<Article>> getAll() async {
    await Future<void>.delayed(delay);
    return _articles.values.toList();
  }

  Future<Article?> getById(String id) async {
    await Future<void>.delayed(delay);
    return _articles[id];
  }
}
