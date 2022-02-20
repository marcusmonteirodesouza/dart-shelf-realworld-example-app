import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  late UserDto author1;
  late UserDto author2;

  setUp(() async {
    author1 = (await registerRandomUserAndUpdateBioAndImage()).user;
    author2 = (await registerRandomUserAndUpdateBioAndImage()).user;
  });

  test('Should order by the most recent articles first', () async {
    final author1Article = await createRandomArticleAndDecode(author1,
        tagList: faker.lorem.words(faker.randomGenerator.integer(5, min: 1)));

    final author2Article = await createRandomArticleAndDecode(author2);

    final articles = await listArticlesAndDecode();

    expect(articles.articles[0].slug, author2Article.slug);
    expect(articles.articles[1].slug, author1Article.slug);
  });

  test('Should limit to 20 articles by default', () async {
    for (var i = 0; i <= 21; i++) {
      await createRandomArticleAndDecode(author1);
    }

    final articles = await listArticlesAndDecode();

    expect(articles.articles.length, 20);
  });

  group('Given no filters', () {
    test('Should return 200', () async {
      final author1Article = await createRandomArticleAndDecode(author1,
          tagList: faker.lorem.words(faker.randomGenerator.integer(5, min: 1)));

      final author2Article = await createRandomArticleAndDecode(author2);

      final articles = await listArticlesAndDecode();

      final author1ArticleFromList =
          articles.articles.firstWhere((a) => a.slug == author1Article.slug);

      final author2ArticleFromList =
          articles.articles.firstWhere((a) => a.slug == author2Article.slug);

      expect(author1ArticleFromList.toJson(), author1Article.toJson());
      expect(author2ArticleFromList.toJson(), author2Article.toJson());
      expect(articles.articlesCount, articles.articles.length);
    });
  });

  group('Given tag filter', () {
    test('Should return 200', () async {
      final tag = faker.lorem.word();

      var author1Article =
          await createRandomArticleAndDecode(author1, tagList: [tag]);

      var author2Article =
          await createRandomArticleAndDecode(author2, tagList: [tag]);

      final articles = await listArticlesAndDecode(tag: tag);

      final author1ArticleFromList =
          articles.articles.firstWhere((a) => a.slug == author1Article.slug);

      final author2ArticleFromList =
          articles.articles.firstWhere((a) => a.slug == author2Article.slug);

      expect(author1ArticleFromList.toJson(), author1Article.toJson());
      expect(author2ArticleFromList.toJson(), author2Article.toJson());
      expect(articles.articlesCount, 2);
    });
  });

  group('Given author filter', () {
    test('Should return 200', () async {
      var author1Article = await createRandomArticleAndDecode(author1);

      var author2Article = await createRandomArticleAndDecode(author2);

      final articles = await listArticlesAndDecode(author: author1.username);

      final author1ArticleFromList =
          articles.articles.firstWhere((a) => a.slug == author1Article.slug);

      expect(author1ArticleFromList.toJson(), author1Article.toJson());
      expect(
          articles.articles.any((a) => a.slug == author2Article.slug), false);
    });
  });

  group('Given favorited filter', () {
    test('Should return 200', () async {
      var author1Article = await createRandomArticleAndDecode(author1);

      await favoriteArticle(author1Article.slug, token: author2.token);

      final articles = await listArticlesAndDecode(
          favoritedByUsername: author2.username, token: author2.token);

      final fetchedArticle = await getArticleAndDecodeBySlug(
          author1Article.slug,
          token: author2.token);

      expect(articles.articlesCount, 1);
      expect(articles.articles[0].toJson(), fetchedArticle.toJson());
    });
  });
}
