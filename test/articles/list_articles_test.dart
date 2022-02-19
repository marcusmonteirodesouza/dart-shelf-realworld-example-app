import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/users_helper.dart';

void main() {
  late UserDto author1;
  late UserDto author2;

  setUp(() async {
    author1 = (await registerRandomUserAndUpdateBioAndImage()).user;
    author2 = (await registerRandomUserAndUpdateBioAndImage()).user;
  });

  group('Given no filters', () {
    test('Should return 200', () async {
      final author1Article = await createRandomArticleAndDecode(
          author: author1, withTagList: true);

      final author2Article = await createRandomArticleAndDecode(
          author: author2, withTagList: false);

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
}
