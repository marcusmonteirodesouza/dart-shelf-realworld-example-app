import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/users_helper.dart';

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
    expect(commentsFromArticle.comments[0].toJson(), articleComment1.toJson());
    expect(commentsFromArticle.comments[1].toJson(), articleComment2.toJson());
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
          token: commentAuthor2.user.token);

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
}
