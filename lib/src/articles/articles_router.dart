import 'dart:convert';

import 'package:dart_shelf_realworld_example_app/src/articles/articles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/article_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/comment_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/list_of_tags_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/multiple_articles_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/dtos/multiple_comments_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/model/article.dart';
import 'package:dart_shelf_realworld_example_app/src/common/errors/dtos/error_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/already_exists_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/argument_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/not_found_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/misc/order_by.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/dtos/profile_dto.dart';
import 'package:dart_shelf_realworld_example_app/src/profiles/profiles_service.dart';
import 'package:dart_shelf_realworld_example_app/src/users/users_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../common/middleware/auth.dart';
import '../users/model/user.dart';
import 'model/comment.dart';

class ArticlesRouter {
  final ArticlesService articlesService;
  final UsersService usersService;
  final ProfilesService profilesService;
  final AuthProvider authProvider;

  ArticlesRouter(
      {required this.articlesService,
      required this.usersService,
      required this.profilesService,
      required this.authProvider});

  Future<Response> _createArticle(Request request) async {
    final user = request.context['user'] as User;

    final requestBody = await request.readAsString();

    final requestData = json.decode(requestBody);

    final articleData = requestData['article'];

    if (articleData == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['article is required'])));
    }

    final title = articleData['title'];
    final description = articleData['description'];
    final body = articleData['body'];
    final tagListData = articleData['tagList'];

    if (title == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['title is required'])));
    }

    if (description == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['description is required'])));
    }

    if (body == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['body is required'])));
    }

    List<String> tagList =
        tagListData == null ? List.empty() : List.from(tagListData);

    Article article;

    try {
      article = await articlesService.createArticle(
          authorId: user.id,
          title: title,
          description: description,
          body: body,
          tagList: tagList);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    } on AlreadyExistsException catch (e) {
      return Response(409, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    final authorProfile = await _getProfileByUserId(user.id);

    final articleDto = ArticleDto(
        slug: article.slug,
        title: article.title,
        description: article.description,
        body: article.body,
        tagList: article.tagList,
        createdAt: article.createdAt,
        updatedAt: article.updatedAt,
        favorited: await articlesService.isFavorited(
            userId: user.id, articleId: article.id),
        favoritesCount: await articlesService.getFavoritesCount(article.id),
        author: authorProfile);

    return Response(201, body: jsonEncode(articleDto));
  }

  Future<Response> _getArticle(Request request) async {
    User? user;
    if (request.context['user'] != null) {
      user = request.context['user'] as User;
    }

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    final authorProfile =
        await _getProfileByUserId(article.authorId, follower: user);

    bool favorited;
    if (user == null) {
      favorited = false;
    } else {
      favorited = await articlesService.isFavorited(
          userId: user.id, articleId: article.id);
    }

    final articleDto = ArticleDto(
        slug: article.slug,
        title: article.title,
        description: article.description,
        body: article.body,
        tagList: article.tagList,
        createdAt: article.createdAt,
        updatedAt: article.updatedAt,
        favorited: favorited,
        favoritesCount: await articlesService.getFavoritesCount(article.id),
        author: authorProfile);

    return Response.ok(jsonEncode(articleDto));
  }

  Future<Response> _listArticles(Request request) async {
    User? user;
    if (request.context['user'] != null) {
      user = request.context['user'] as User;
    }

    final tag = request.url.queryParameters['tag'];
    final authorUsername = request.url.queryParameters['author'];
    final favoritedByUsername = request.url.queryParameters['favorited'];
    final limitParam = request.url.queryParameters['limit'];
    final offsetParam = request.url.queryParameters['offset'];

    String? authorId;
    if (authorUsername != null) {
      final author = await usersService.getUserByUsername(authorUsername);

      if (author == null) {
        return Response.notFound(
            jsonEncode(ErrorDto(errors: ['Author not found'])));
      }

      authorId = author.id;
    }

    String? favoritedByUserId;
    if (favoritedByUsername != null) {
      final favoritedByUser =
          await usersService.getUserByUsername(favoritedByUsername);

      if (favoritedByUser == null) {
        return Response.notFound(
            jsonEncode(ErrorDto(errors: ['User not found'])));
      }

      favoritedByUserId = favoritedByUser.id;
    }

    int? limit;
    if (limitParam != null) {
      limit = int.tryParse(limitParam);

      if (limit == null) {
        return Response(422,
            body: jsonEncode(ErrorDto(errors: ['Invalid limit'])));
      }
    } else {
      limit = 20; // Default
    }

    int? offset;
    if (offsetParam != null) {
      offset = int.tryParse(offsetParam);

      if (offset == null) {
        return Response(422,
            body: jsonEncode(ErrorDto(errors: ['Invalid offset'])));
      }
    }

    final orderBy = OrderBy(property: 'created_at', order: Order.desc);

    List<Article> articles;

    try {
      articles = await articlesService.listArticles(
          tag: tag,
          authorId: authorId,
          favoritedByUserId: favoritedByUserId,
          limit: limit,
          offset: offset,
          orderBy: orderBy);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    final articlesDtos = <ArticleDto>[];

    for (final article in articles) {
      final articleAuthor = await usersService.getUserById(article.authorId);

      if (articleAuthor == null) {
        throw AssertionError('Article author not found');
      }

      var favorited = false;
      if (user != null) {
        favorited = await articlesService.isFavorited(
            userId: user.id, articleId: article.id);
      }

      final authorProfile =
          await _getProfileByUserId(article.authorId, follower: user);

      final articleDto = ArticleDto(
          slug: article.slug,
          title: article.title,
          description: article.description,
          body: article.body,
          tagList: article.tagList,
          createdAt: article.createdAt,
          updatedAt: article.updatedAt,
          favorited: favorited,
          favoritesCount: await articlesService.getFavoritesCount(article.id),
          author: authorProfile);

      articlesDtos.add(articleDto);
    }

    final multipleArticlesDto = MultipleArticlesDto(articles: articlesDtos);

    return Response.ok(jsonEncode(multipleArticlesDto));
  }

  Future<Response> _updateArticle(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    final requestBody = await request.readAsString();

    final requestData = json.decode(requestBody);

    final articleData = requestData['article'];

    if (articleData == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['article is required'])));
    }

    final title = articleData['title'];
    final description = articleData['description'];
    final body = articleData['body'];
    final tagListData = articleData['tagList'];

    List<String>? tagList = tagListData == null ? null : List.from(tagListData);

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    if (article.authorId != user.id) {
      return Response(403);
    }

    Article updatedArticle;

    try {
      updatedArticle = await articlesService.updateArticleById(article.id,
          title: title, description: description, body: body, tagList: tagList);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    final authorProfile =
        await _getProfileByUserId(article.authorId, follower: user);

    final articleDto = ArticleDto(
        slug: updatedArticle.slug,
        title: updatedArticle.title,
        description: updatedArticle.description,
        body: updatedArticle.body,
        tagList: updatedArticle.tagList,
        createdAt: updatedArticle.createdAt,
        updatedAt: updatedArticle.updatedAt,
        favorited: await articlesService.isFavorited(
            userId: user.id, articleId: article.id),
        favoritesCount: await articlesService.getFavoritesCount(article.id),
        author: authorProfile);

    return Response.ok(jsonEncode(articleDto));
  }

  Future<Response> _deleteArticle(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    if (article.authorId != user.id) {
      return Response(403);
    }

    await articlesService.deleteArticleBySlug(slug);

    return Response(204);
  }

  Future<Response> _favoriteArticle(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    var article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    final author = await usersService.getUserById(article.authorId);

    if (author == null) {
      throw AssertionError('Author not found');
    }

    await articlesService.createFavorite(
        userId: user.id, articleId: article.id);

    final authorProfile = await _getProfileByUserId(author.id, follower: user);

    final articleDto = ArticleDto(
        slug: article.slug,
        title: article.title,
        description: article.description,
        body: article.body,
        tagList: article.tagList,
        createdAt: article.createdAt,
        updatedAt: article.updatedAt,
        favorited: await articlesService.isFavorited(
            userId: user.id, articleId: article.id),
        favoritesCount: await articlesService.getFavoritesCount(article.id),
        author: authorProfile);

    return Response.ok(json.encode(articleDto));
  }

  Future<Response> _unFavoriteArticle(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    var article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    await articlesService.deleteFavoriteByUserIdAndArticleId(
        userId: user.id, articleId: article.id);

    final authorProfile =
        await _getProfileByUserId(article.authorId, follower: user);

    final articleDto = ArticleDto(
        slug: article.slug,
        title: article.title,
        description: article.description,
        body: article.body,
        tagList: article.tagList,
        createdAt: article.createdAt,
        updatedAt: article.updatedAt,
        favorited: await articlesService.isFavorited(
            userId: user.id, articleId: article.id),
        favoritesCount: await articlesService.getFavoritesCount(article.id),
        author: authorProfile);

    return Response.ok(jsonEncode(articleDto));
  }

  Future<Response> _addCommentToArticle(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    final requestBody = await request.readAsString();

    final requestData = json.decode(requestBody);

    final commentData = requestData['comment'];

    if (commentData == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['comment is required'])));
    }

    final body = commentData['body'];

    if (body == null) {
      return Response(422,
          body: jsonEncode(ErrorDto(errors: ['body is required'])));
    }

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    Comment comment;
    try {
      comment = await articlesService.createComment(
          authorId: user.id, articleId: article.id, body: body);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    final userProfile = await _getProfileByUserId(user.id);

    final commentDto = CommentDto(
        id: comment.id,
        createdAt: comment.createdAt,
        updatedAt: comment.updatedAt,
        body: comment.body,
        author: userProfile);

    return Response(201, body: jsonEncode(commentDto));
  }

  Future<Response> _getCommentsFromArticle(Request request) async {
    User? user;
    if (request.context['user'] != null) {
      user = request.context['user'] as User;
    }

    final slug = request.params['slug'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    List<Comment> comments;
    try {
      comments = await articlesService.listComments(articleId: article.id);
    } on ArgumentException catch (e) {
      return Response(422, body: jsonEncode(ErrorDto(errors: [e.message])));
    }

    List<CommentDto> commentDtos = <CommentDto>[];

    for (final comment in comments) {
      final authorProfile =
          await _getProfileByUserId(comment.authorId, follower: user);

      final commentDto = CommentDto(
          id: comment.id,
          createdAt: comment.createdAt,
          updatedAt: comment.updatedAt,
          body: comment.body,
          author: authorProfile);

      commentDtos.add(commentDto);
    }

    return Response.ok(jsonEncode(MultipleCommentsDto(comments: commentDtos)));
  }

  Future<Response> _deleteComment(Request request) async {
    final user = request.context['user'] as User;

    final slug = request.params['slug'];
    final commentId = request.params['commentId'];

    if (slug == null) {
      throw AssertionError('slug must be in the request params');
    }

    if (commentId == null) {
      throw AssertionError('commentId must be in the request params');
    }

    final article = await articlesService.getArticleBySlug(slug);

    if (article == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Article not found'])));
    }

    final comment = await articlesService.getCommentById(commentId);

    if (comment == null) {
      return Response.notFound(
          jsonEncode(ErrorDto(errors: ['Comment not found'])));
    }

    if (comment.authorId != user.id) {
      return Response(403);
    }

    await articlesService.deleteCommentById(commentId);

    return Response(204);
  }

  Future<Response> _getTags(Request request) async {
    final tags = await articlesService.listTags();

    final listOfTagsDto = ListOfTagsDto(tags: tags);

    return Response.ok(jsonEncode(listOfTagsDto));
  }

  Future<ProfileDto> _getProfileByUserId(String userId,
      {User? follower}) async {
    final user = await usersService.getUserById(userId);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    var following = false;
    if (follower != null) {
      following = await profilesService.isFollowing(
          followerId: follower.id, followeeId: user.id);
    }

    return ProfileDto(
        username: user.username,
        bio: user.bio,
        image: user.image,
        following: following);
  }

  Handler get router {
    final router = Router();

    router.post(
        '/articles',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_createArticle));

    router.post(
        '/articles/<slug>/favorite',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_favoriteArticle));

    router.post(
        '/articles/<slug>/comments',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_addCommentToArticle));

    router.get(
        '/articles/<slug>',
        Pipeline()
            .addMiddleware(authProvider.optionalAuth())
            .addHandler(_getArticle));

    router.get(
        '/articles',
        Pipeline()
            .addMiddleware(authProvider.optionalAuth())
            .addHandler(_listArticles));

    router.get(
        '/articles/<slug>/comments',
        Pipeline()
            .addMiddleware(authProvider.optionalAuth())
            .addHandler(_getCommentsFromArticle));

    router.get('/tags', _getTags);

    router.put(
        '/articles/<slug>',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_updateArticle));

    router.delete(
        '/articles/<slug>',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_deleteArticle));

    router.delete(
        '/articles/<slug>/favorite',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_unFavoriteArticle));

    router.delete(
        '/articles/<slug>/comments/<commentId>',
        Pipeline()
            .addMiddleware(authProvider.requireAuth())
            .addHandler(_deleteComment));

    return router;
  }
}
