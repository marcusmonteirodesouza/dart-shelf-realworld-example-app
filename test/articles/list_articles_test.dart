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
}
