import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/profiles_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  late UserDto articleAuthor;
  late ArticleDto article;

  setUp(() async {
    articleAuthor = (await registerRandomUserAndUpdateBioAndImage()).user;
    article = await createRandomArticleAndDecode(articleAuthor);
  });

  test('Should order from the oldest to the newest comment by default',
      () async {
    final commentAuthor1 = await registerRandomUser();
    final commentAuthor2 = await registerRandomUser();

    final articleComment1 = await createdRandomComment(article.slug,
        token: commentAuthor1.user.token);

    final articleComment2 = await createdRandomComment(article.slug,
        token: commentAuthor2.user.token);

    final commentsFromArticle =
        await getCommentsFromArticleAndDecode(article.slug);

    expect(commentsFromArticle.comments.length, 2);

    expect(articleComment1.author.following, false);
    expect(articleComment2.author.following, false);

    expect(commentsFromArticle.comments[0].toJson(), articleComment1.toJson());
    expect(commentsFromArticle.comments[1].toJson(), articleComment2.toJson());
  });

  test('Should not return deleted comments', () async {
    final commentAuthor = await registerRandomUser();

    final comment = await createdRandomComment(article.slug,
        token: commentAuthor.user.token);

    await deleteCommentById(
        slug: article.slug,
        commentId: comment.id,
        token: commentAuthor.user.token);

    final comments = await getCommentsFromArticleAndDecode(article.slug);

    expect(comments.comments.any((c) => c.id == comment.id), false);
  });

  group('Given caller is not authenticated', () {
    test('Should return 200', () async {
      final commentAuthor1 = await registerRandomUser();
      final commentAuthor2 = await registerRandomUser();
      final anotherArticle = await createRandomArticleAndDecode(articleAuthor);

      final articleComment1 = await createdRandomComment(article.slug,
          token: commentAuthor1.user.token);

      final articleComment2 = await createdRandomComment(article.slug,
          token: commentAuthor2.user.token);

      await createdRandomComment(anotherArticle.slug,
          token: commentAuthor1.user.token);

      final commentsFromArticle =
          await getCommentsFromArticleAndDecode(article.slug);

      final articleComment1FromList = commentsFromArticle.comments
          .firstWhere((c) => c.id == articleComment1.id);

      final articleComment2FromList = commentsFromArticle.comments
          .firstWhere((c) => c.id == articleComment2.id);

      expect(commentsFromArticle.comments.length, 2);
      expect(articleComment1FromList.toJson(), articleComment1.toJson());
      expect(articleComment2FromList.toJson(), articleComment2.toJson());
    });
  });

  group('Given caller is authenticated', () {
    late UserDto caller;

    setUp(() async {
      caller = (await registerRandomUserAndUpdateBioAndImage()).user;
    });

    test('Given caller follows comment author should return 200', () async {
      final commentAuthor1 = await registerRandomUser();
      final commentAuthor2 = await registerRandomUser();
      final commentAuthor3 = await registerRandomUser();
      final anotherArticle = await createRandomArticleAndDecode(articleAuthor);

      await followUserByUsername(commentAuthor1.user.username,
          token: caller.token);

      await followUserByUsername(commentAuthor3.user.username,
          token: caller.token);

      final articleComment1 = await createdRandomComment(article.slug,
          token: commentAuthor1.user.token);

      final articleComment2 = await createdRandomComment(article.slug,
          token: commentAuthor2.user.token);

      final articleComment3 = await createdRandomComment(article.slug,
          token: commentAuthor3.user.token);

      await createdRandomComment(anotherArticle.slug,
          token: commentAuthor1.user.token);

      final commentsFromArticle = await getCommentsFromArticleAndDecode(
          article.slug,
          token: caller.token);

      final articleComment1FromList = commentsFromArticle.comments
          .firstWhere((c) => c.id == articleComment1.id);

      final articleComment2FromList = commentsFromArticle.comments
          .firstWhere((c) => c.id == articleComment2.id);

      final articleComment3FromList = commentsFromArticle.comments
          .firstWhere((c) => c.id == articleComment3.id);

      expect(commentsFromArticle.comments.length, 3);

      expect(articleComment1FromList.author.following, true);
      expect(articleComment2FromList.author.following, false);
      expect(articleComment3FromList.author.following, true);
    });
  });

  test('Given Article does not exist should return 404', () async {
    final slug = faker.guid.guid();

    final response = await getCommentsFromArticle(slug);

    expect(response.statusCode, 404);

    final responseJson = jsonDecode(response.body);

    final error = ErrorDto.fromJson(responseJson);

    expect(error.errors[0], 'Article not found');
  });
}
