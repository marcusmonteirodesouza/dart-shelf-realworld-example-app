import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';

class MultipleArticlesDto {
  final List<ArticleDto> articles;

  MultipleArticlesDto({required this.articles});

  int get articlesCount {
    return articles.length;
  }

  MultipleArticlesDto.fromJson(Map<String, dynamic> json)
      : articles = List.from(json['articles'])
            .map((a) => ArticleDto.fromJson(a))
            .toList();

  Map<String, dynamic> toJson() => {
        'articles': articles.map((a) => a.toJson()).toList(),
        'articlesCount': articlesCount
      };
}
