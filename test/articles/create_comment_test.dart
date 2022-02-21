import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  late UserDto articleAuthor;
  late ArticleDto article;
  late UserDto commentAuthor;

  setUp(() async {
    articleAuthor = (await registerRandomUser()).user;
    article = await createRandomArticleAndDecode(articleAuthor);
    commentAuthor = (await registerRandomUserAndUpdateBioAndImage()).user;
  });

  test('Should return 200', () async {
    final body = faker.lorem.sentence();

    final comment = await createCommentAndDecode(article.slug,
        token: commentAuthor.token, body: body);

    final commentsFromArticle =
        await getCommentsFromArticleAndDecode(article.slug);

    expect(comment.author.username, commentAuthor.username);
    expect(comment.author.following, false);
    expect(comment.author.bio, commentAuthor.bio);
    expect(comment.author.image, commentAuthor.image);

    expect(comment.toJson(), commentsFromArticle.comments[0].toJson());
  });

  test('Given no comment should return 422', () async {
    final headers = makeHeadersWithAuthorization(commentAuthor.token);

    final requestData = {};

    final response = await post(createCommentUri(article.slug),
        headers: headers, body: jsonEncode(requestData));

    expect(response.statusCode, 422);

    final responseJson = jsonDecode(response.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'comment is required');
  });

  group('body validation', () {
    test('Given no body should return 422', () async {
      final headers = makeHeadersWithAuthorization(commentAuthor.token);

      final requestData = {'comment': {}};

      final response = await post(createCommentUri(article.slug),
          headers: headers, body: jsonEncode(requestData));

      expect(response.statusCode, 422);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'body is required');
    });

    test('Given body is empty should return 422', () async {
      final body = '';

      final response = await createComment(article.slug,
          token: commentAuthor.token, body: body);

      expect(response.statusCode, 422);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'body cannot be blank');
    });

    test('Given body is whitespace should return 422', () async {
      final body = ' ';

      final response = await createComment(article.slug,
          token: commentAuthor.token, body: body);

      expect(response.statusCode, 422);

      final responseJson = jsonDecode(response.body);

      final error = ErrorDto.fromJson(responseJson);

      expect(error.errors[0], 'body cannot be blank');
    });
  });

  group('authorization', () {
    test('Given no authorization header should return 401', () async {
      final response = await post(createCommentUri(article.slug));

      expect(response.statusCode, 401);
    });

    test('Given invalid authorization header should return 401', () async {
      final headers = {'Authorization': 'invalid'};
      final response =
          await post(createCommentUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given no token should return 401', () async {
      final headers = {'Authorization': 'Token '};
      final response =
          await post(createCommentUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given user is not found should return 401', () async {
      final email = faker.internet.email();
      final token = makeTokenWithEmail(email);

      final headers = {'Authorization': 'Token $token'};

      final response =
          await post(createCommentUri(article.slug), headers: headers);

      expect(response.statusCode, 401);
    });
  });
}
