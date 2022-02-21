import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/comment_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:http/http.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  late ArticleDto article;
  late UserDto commentAuthor;

  setUp(() async {
    final articleAuthor = (await registerRandomUserAndUpdateBioAndImage()).user;
    article = await createRandomArticleAndDecode(articleAuthor);
    commentAuthor = (await registerRandomUser()).user;
  });

  test('Should return 204', () async {
    final comment =
        await createdRandomComment(article.slug, token: commentAuthor.token);

    final deleteCommentResponse = await deleteCommentById(
        slug: article.slug, commentId: comment.id, token: commentAuthor.token);

    expect(deleteCommentResponse.statusCode, 204);

    final articleComments = await getCommentsFromArticleAndDecode(article.slug);

    expect(articleComments.comments.length, 0);
  });

  test('Given Article does not exist should return 404', () async {
    final slug = faker.guid.guid();

    final comment =
        await createdRandomComment(article.slug, token: commentAuthor.token);

    final response = await deleteCommentById(
        slug: slug, commentId: comment.id, token: commentAuthor.token);

    expect(response.statusCode, 404);

    final responseJson = jsonDecode(response.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Article not found');
  });

  test('Given Comment does not exist should return 404', () async {
    final commentId = faker.guid.guid();

    final response = await deleteCommentById(
        slug: article.slug, commentId: commentId, token: commentAuthor.token);

    expect(response.statusCode, 404);

    final responseJson = jsonDecode(response.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Comment not found');
  });

  group('authorization', () {
    late CommentDto comment;
    late Uri uri;

    setUp(() async {
      comment =
          await createdRandomComment(article.slug, token: commentAuthor.token);
      uri = deleteCommentByIdUri(slug: article.slug, commentId: comment.id);
    });

    test('Given no authorization header should return 401', () async {
      final response = await delete(uri);

      expect(response.statusCode, 401);
    });

    test('Given invalid authorization header should return 401', () async {
      final headers = {'Authorization': 'invalid'};
      final response = await delete(uri, headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given no token should return 401', () async {
      final headers = {'Authorization': 'Token '};
      final response = await delete(uri, headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given user is not found should return 401', () async {
      final email = faker.internet.email();
      final token = makeTokenWithEmail(email);

      final headers = {'Authorization': 'Token $token'};

      final response = await delete(uri, headers: headers);

      expect(response.statusCode, 401);
    });

    test('Given wrong token should return 403', () async {
      final anotherUser = await registerRandomUser();

      final response = await deleteCommentById(
          slug: article.slug,
          commentId: comment.id,
          token: anotherUser.user.token);

      expect(response.statusCode, 403);
    });
  });
}
