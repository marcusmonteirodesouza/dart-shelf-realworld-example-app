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

  setUp(() async {
    author = (await registerRandomUserAndUpdateBioAndImage()).user;
  });

  test('Should return 204', () async {
    final article =
        await createRandomArticleAndDecode(author: author, withTagList: false);

    final deleteArticleResponse =
        await deleteArticleBySlug(article.slug, token: author.token);

    expect(deleteArticleResponse.statusCode, 204);

    final getArticleResponse = await getArticleBySlug(article.slug);

    expect(getArticleResponse.statusCode, 404);

    final responseJson = jsonDecode(getArticleResponse.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Article not found');
  });

  test('Given Article does not exists should return 404', () async {
    final slug = slugify(faker.lorem.sentence());

    final deleteArticleResponse =
        await deleteArticleBySlug(slug, token: author.token);

    expect(deleteArticleResponse.statusCode, 404);

    final responseJson = jsonDecode(deleteArticleResponse.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Article not found');
  });

  group('authorization', () {
    late ArticleDto article;

    setUp(() async {
      article = await createRandomArticleAndDecode(
          author: author, withTagList: false);
    });

    test('Given no authorization header should return 401', () async {
      final response = await delete(deleteArticleBySlugUri(article.slug));

      expect(response.statusCode, 401);
    });

    test('Given invalid authorization header should return 401', () async {
      final headers = {'Authorization': 'invalid'};
      final response =
          await delete(deleteArticleBySlugUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given no token should return 401', () async {
      final headers = {'Authorization': 'Token '};
      final response =
          await delete(deleteArticleBySlugUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given user is not found should return 401', () async {
      final email = faker.internet.email();
      final token = makeTokenWithEmail(email);

      final headers = {'Authorization': 'Token $token'};

      final response =
          await delete(deleteArticleBySlugUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given wrong token should return 403', () async {
      final anotherUser = await registerRandomUser();

      final response = await deleteArticleBySlug(article.slug,
          token: anotherUser.user.token);

      expect(response.statusCode, 403);
    });
  });
}
