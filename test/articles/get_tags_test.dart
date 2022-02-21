import 'package:test/test.dart';

import '../helpers/articles_helper.dart';
import '../helpers/users_helper.dart';
import '../test_fixtures.dart';

void main() {
  test('Should return 200', () async {
    final tags = await getTagsAndDecode();

    for (var i = 0; i <= faker.randomGenerator.integer(5, min: 1); i++) {
      final author = await registerRandomUser();
      await createRandomArticleAndDecode(author.user);
    }

    // Get all articles
    final articles = await listArticlesAndDecode(limit: 4294967296);

    final articlesTags = articles.articles
        .map((a) => a.tagList)
        .expand((tagLists) => tagLists)
        .toSet()
        .toList();

    articlesTags.sort();

    expect(tags.tags, articlesTags);
  });
}
