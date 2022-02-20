import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
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

    test('Given no tags were found should return 200', () async {
      final tag = faker.guid.guid();

      final articles = await listArticlesAndDecode(tag: tag);

      expect(articles.articles.isEmpty, true);
      expect(articles.articlesCount, 0);
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

    test('Given Author is not found should return 404', () async {
      final author = faker.internet.userName();

      final response = await listArticles(author: author);

      expect(response.statusCode, 404);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'Author not found');
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

    test('Given User is not found should return 404', () async {
      final username = faker.internet.userName();

      final response = await listArticles(favoritedByUsername: username);

      expect(response.statusCode, 404);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'User not found');
    });
  });

  group('Given limit', () {
    test('Should return 200', () async {
      final limit = faker.randomGenerator.integer(30, min: 1);

      for (var i = 0; i <= limit; i++) {
        await createRandomArticleAndDecode(author1);
      }

      final articles = await listArticlesAndDecode(limit: limit);

      expect(articles.articlesCount, limit);
    });

    test('Given limit is zero should return 200', () async {
      final limit = 0;

      final articles = await listArticlesAndDecode(limit: limit);

      expect(articles.articles.isEmpty, true);
      expect(articles.articlesCount, 0);
    });

    test('Given limit is negative should return 422', () async {
      final limit = -1;

      final response = await listArticles(limit: limit);

      expect(response.statusCode, 422);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'limit must be positive');
    });
  });
}
