import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
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

  setUp(() async {
    articleAuthor = (await registerRandomUserAndUpdateBioAndImage()).user;
    article = await createRandomArticleAndDecode(articleAuthor);
  });

  test('Should return 200', () async {
    final caller = await registerRandomUserAndUpdateBioAndImage();

    final body = faker.lorem.sentence();

    final comment = await createCommentAndDecode(article.slug,
        token: caller.user.token, body: body);

    final commentsFromArticle =
        await getCommentsFromArticleAndDecode(article.slug);

    expect(comment.author.username, caller.user.username);
    expect(comment.author.following, false);
    expect(comment.author.bio, caller.user.bio);
    expect(comment.author.image, caller.user.image);

    expect(comment.toJson(), commentsFromArticle.comments[0].toJson());
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
