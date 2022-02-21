import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:http/http.dart';
import 'package:slugify/slugify.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  late UserDto author;
  late UserDto caller;

  setUp(() async {
    author = (await registerRandomUserAndUpdateBioAndImage()).user;
    caller = (await registerRandomUserAndUpdateBioAndImage()).user;
  });

  test('Should return 200', () async {
    final article = await createRandomArticleAndDecode(author);

    final favoritedArticle =
        await favoriteArticleAndDecodeBySlug(article.slug, token: caller.token);

    final fetchedArticle =
        await getArticleAndDecodeBySlug(article.slug, token: caller.token);

    expect(favoritedArticle.favorited, true);
    expect(favoritedArticle.favoritesCount, article.favoritesCount + 1);
    expect(favoritedArticle.toJson(), fetchedArticle.toJson());
  });

  test('Given article previously unfavorited should return 200', () async {
    final article = await createRandomArticleAndDecode(author);

    await favoriteArticleBySlug(article.slug, token: caller.token);

    await unFavoriteArticleBySlug(article.slug, token: caller.token);

    final favoritedArticle =
        await favoriteArticleAndDecodeBySlug(article.slug, token: caller.token);

    final fetchedArticle =
        await getArticleAndDecodeBySlug(article.slug, token: caller.token);

    expect(favoritedArticle.favorited, true);
    expect(favoritedArticle.favoritesCount, article.favoritesCount + 1);
    expect(favoritedArticle.toJson(), fetchedArticle.toJson());
  });

  test('Given article does not exists should return 404', () async {
    final slug = slugify(faker.lorem.sentence());

    final response = await favoriteArticleBySlug(slug, token: caller.token);

    expect(response.statusCode, 404);

    final responseJson = jsonDecode(response.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Article not found');
  });

  group('authorization', () {
    late ArticleDto article;
    late Uri uri;

    setUp(() async {
      article = await createRandomArticleAndDecode(author);
      uri = favoriteArticleUri(article.slug);
    });

    test('Given no authorization header should return 401', () async {
      final response = await post(uri);

      expect(response.statusCode, 401);
    });

    test('Given invalid authorization header should return 401', () async {
      final headers = {'Authorization': 'invalid'};
      final response = await post(uri, headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given no token should return 401', () async {
      final headers = {'Authorization': 'Token '};
      final response = await post(uri, headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given user is not found should return 401', () async {
      final email = faker.internet.email();
      final token = makeTokenWithEmail(email);

      final headers = {'Authorization': 'Token $token'};

      final response = await post(uri, headers: headers);

      expect(response.statusCode, 401);
    });
  });
}
