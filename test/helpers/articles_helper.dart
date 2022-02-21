import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/comment_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/multiple_articles_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/multiple_comments_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/users/dtos/user_dto.dart';
import 'package:http/http.dart';
import 'package:slugify/slugify.dart';
import 'package:test/expect.dart';

import '../test_fixtures.dart';
import 'auth_helper.dart';
import 'profiles_helper.dart';

Uri createArticleUri() {
  return Uri.parse(host + '/articles');
}

Future<Response> createArticle(
    {required String token,
    required String title,
    required String description,
    required String body,
    List<String>? tagList}) async {
  final headers = makeHeadersWithAuthorization(token);

  final requestData = {
    'article': {
      'title': title,
      'description': description,
      'body': body,
      'tagList': tagList
    }
  };

  return await post(createArticleUri(),
      headers: headers, body: jsonEncode(requestData));
}

Future<ArticleDto> createArticleAndDecode(UserDto author,
    {required String title,
    required String description,
    required String body,
    List<String>? tagList}) async {
  final response = await createArticle(
      token: author.token,
      title: title,
      description: description,
      body: body,
      tagList: tagList);

  expect(response.statusCode, 201);

  final responseJson = json.decode(response.body);

  final article = ArticleDto.fromJson(responseJson);

  final authorProfile =
      await getProfileByUsernameAndDecode(author.username, token: author.token);

  final now = DateTime.now();

  expect(article.title, title);
  expect(article.slug, slugify(author.username + ' ' + article.title));
  expect(article.description, description);
  expect(article.body, body);
  expect(now.difference(article.createdAt).inSeconds < 1, true);
  expect(article.updatedAt.isAtSameMomentAs(article.createdAt), true);
  expect(article.author.toJson(), authorProfile.toJson());

  return article;
}

Future<ArticleDto> createRandomArticleAndDecode(UserDto author,
    {String? title,
    String? description,
    String? body,
    List<String>? tagList}) async {
  title ??=
      faker.lorem.sentences(faker.randomGenerator.integer(8, min: 1)).join(' ');
  description ??=
      faker.lorem.sentences(faker.randomGenerator.integer(8, min: 1)).join(' ');
  body ??= faker.lorem
      .sentences(faker.randomGenerator.integer(20, min: 1))
      .join(' ');

  return await createArticleAndDecode(author,
      title: title, description: description, body: body, tagList: tagList);
}

Uri getArticleBySlugUri(String slug) {
  return Uri.parse(host + '/articles/$slug');
}

Future<Response> getArticleBySlug(String slug, {String? token}) async {
  Map<String, String> headers = {};

  if (token != null) {
    headers = makeHeadersWithAuthorization(token);
  }

  return await get(getArticleBySlugUri(slug), headers: headers);
}

Future<ArticleDto> getArticleAndDecodeBySlug(String slug,
    {String? token}) async {
  final response = await getArticleBySlug(slug, token: token);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  return ArticleDto.fromJson(responseJson);
}

Uri listArticlesUri(
    {String? tag,
    String? author,
    String? favoritedByUsername,
    int? limit,
    int? offset}) {
  Map<String, dynamic> queryParameters = {};

  if (tag != null) {
    queryParameters['tag'] = tag;
  }

  if (author != null) {
    queryParameters['author'] = author;
  }

  if (favoritedByUsername != null) {
    queryParameters['favorited'] = favoritedByUsername;
  }

  if (limit != null) {
    queryParameters['limit'] = limit.toString();
  }

  if (offset != null) {
    queryParameters['offset'] = offset.toString();
  }

  if (Uri.parse(host).isScheme('http')) {
    return Uri.http(authority, '/$apiPath/articles', queryParameters);
  } else if (Uri.parse(host).isScheme('https')) {
    return Uri.https(authority, '/$apiPath/articles', queryParameters);
  } else {
    throw UnsupportedError('Unsupported host scheme ${Uri.parse(host).scheme}');
  }
}

Future<Response> listArticles(
    {String? token,
    String? tag,
    String? author,
    String? favoritedByUsername,
    int? limit,
    int? offset}) async {
  Map<String, String> headers = {};

  if (token != null) {
    headers = makeHeadersWithAuthorization(token);
  }

  return await get(
      listArticlesUri(
          tag: tag,
          author: author,
          favoritedByUsername: favoritedByUsername,
          limit: limit,
          offset: offset),
      headers: headers);
}

Future<MultipleArticlesDto> listArticlesAndDecode(
    {String? token,
    String? tag,
    String? author,
    String? favoritedByUsername,
    int? limit,
    int? offset}) async {
  final response = await listArticles(
      token: token,
      tag: tag,
      author: author,
      favoritedByUsername: favoritedByUsername,
      limit: limit,
      offset: offset);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  return MultipleArticlesDto.fromJson(responseJson);
}

Uri updateArticleBySlugUri(String slug) {
  return Uri.parse(host + '/articles/$slug');
}

Future<Response> updateArticleBySlug(String slug,
    {required String token,
    String? title,
    String? description,
    String? body}) async {
  final requestData = {'article': {}};

  if (title != null) {
    requestData['article']?['title'] = title;
  }

  if (description != null) {
    requestData['article']?['description'] = description;
  }

  if (body != null) {
    requestData['article']?['body'] = body;
  }

  if (title != null) {
    requestData['article']?['title'] = title;
  }

  final headers = makeHeadersWithAuthorization(token);

  return await put(updateArticleBySlugUri(slug),
      headers: headers, body: jsonEncode(requestData));
}

Future<ArticleDto> updateArticleBySlugAndDecode(String slug,
    {required String token,
    String? title,
    String? description,
    String? body}) async {
  final response = await updateArticleBySlug(slug,
      token: token, title: title, description: description, body: body);

  expect(response.statusCode, 200);

  final responseJson = json.decode(response.body);

  return ArticleDto.fromJson(responseJson);
}

Uri deleteArticleBySlugUri(String slug) {
  return Uri.parse(host + '/articles/$slug');
}

Future<Response> deleteArticleBySlug(String slug,
    {required String token}) async {
  final headers = makeHeadersWithAuthorization(token);

  return await delete(deleteArticleBySlugUri(slug), headers: headers);
}

Uri favoriteArticleUri(String slug) {
  return Uri.parse(host + '/articles/$slug/favorite');
}

Future<Response> favoriteArticleBySlug(String slug,
    {required String token}) async {
  final headers = makeHeadersWithAuthorization(token);

  return await post(favoriteArticleUri(slug), headers: headers);
}

Future<ArticleDto> favoriteArticleAndDecodeBySlug(String slug,
    {required String token}) async {
  final response = await favoriteArticleBySlug(slug, token: token);

  expect(response.statusCode, 200);

  final responseJson = json.decode(response.body);

  return ArticleDto.fromJson(responseJson);
}

Uri unFavoriteArticleUri(String slug) {
  return Uri.parse(host + '/articles/$slug/favorite');
}

Future<Response> unFavoriteArticleBySlug(String slug,
    {required String token}) async {
  final headers = makeHeadersWithAuthorization(token);

  return await delete(unFavoriteArticleUri(slug), headers: headers);
}

Future<ArticleDto> unFavoriteArticleAndDecodeBySlug(String slug,
    {required String token}) async {
  final response = await unFavoriteArticleBySlug(slug, token: token);

  expect(response.statusCode, 200);

  final responseJson = json.decode(response.body);

  return ArticleDto.fromJson(responseJson);
}

Uri createCommentUri(String slug) {
  return Uri.parse(host + '/articles/$slug/comments');
}

Future<Response> createComment(String slug,
    {required String token, required String body}) async {
  final headers = makeHeadersWithAuthorization(token);

  final requestData = {
    'comment': {
      'body': body,
    }
  };

  return await post(createCommentUri(slug),
      headers: headers, body: jsonEncode(requestData));
}

Future<CommentDto> createCommentAndDecode(String slug,
    {required String token, required String body}) async {
  final response = await createComment(slug, token: token, body: body);

  expect(response.statusCode, 201);

  final responseJson = json.decode(response.body);

  final comment = CommentDto.fromJson(responseJson);

  final now = DateTime.now();

  expect(comment.createdAt.difference(now).inSeconds < 1, true);
  expect(comment.updatedAt.isAtSameMomentAs(comment.createdAt), true);
  expect(comment.body, body);

  return comment;
}

Future<CommentDto> createdRandomComment(String slug,
    {required String token}) async {
  final body =
      faker.lorem.sentences(faker.randomGenerator.integer(6, min: 1)).join(' ');

  return await createCommentAndDecode(slug, token: token, body: body);
}

Uri getCommentsFromArticleUri(String slug) {
  return Uri.parse(host + '/articles/$slug/comments');
}

Future<Response> getCommentsFromArticle(String slug, {String? token}) {
  Map<String, String> headers = {};

  if (token != null) {
    headers = makeHeadersWithAuthorization(token);
  }

  return get(getCommentsFromArticleUri(slug), headers: headers);
}

Future<MultipleCommentsDto> getCommentsFromArticleAndDecode(String slug,
    {String? token}) async {
  final response = await getCommentsFromArticle(slug, token: token);

  expect(response.statusCode, 200);

  final responseJson = jsonDecode(response.body);

  return MultipleCommentsDto.fromJson(responseJson);
}

Uri deleteCommentByIdUri({required String slug, required String commentId}) {
  return Uri.parse(host + '/articles/$slug/comments/$commentId');
}

Future<Response> deleteCommentById(
    {required String slug,
    required String commentId,
    required String token}) async {
  final headers = makeHeadersWithAuthorization(token);

  return await delete(deleteCommentByIdUri(slug: slug, commentId: commentId),
      headers: headers);
}
