import 'package:dart_shelf_realworld_example_app/src/articles/model/article.dart';
import 'package:dart_shelf_realworld_example_app/src/articles/model/favorite.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/already_exists_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/argument_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/exceptions/not_found_exception.dart';
import 'package:dart_shelf_realworld_example_app/src/common/misc/order_by.dart';
import 'package:postgres_pool/postgres_pool.dart';
import 'package:slugify/slugify.dart';

import '../users/users_service.dart';
import 'model/comment.dart';

class ArticlesService {
  static String articlesTable = 'articles';
  static String favoritesTable = 'favorites';
  static String commentsTable = 'comments';

  final PgPool connectionPool;
  final UsersService usersService;

  ArticlesService({required this.connectionPool, required this.usersService});

  Future<Article> createArticle(
      {required String authorId,
      required String title,
      required String description,
      required String body,
      required List<String> tagList}) async {
    _validateTitleOrThrow(title);

    _validateDescriptionOrThrow(description);

    _validateBodyOrThrow(body);

    final author = await usersService.getUserById(authorId);

    if (author == null) {
      throw ArgumentException(
          message: 'User not found', parameterName: 'authorId');
    }

    final slug = _makeSlug(author.username, title);

    await _validateSlugOrThrow(slug);

    final hasDeletedArticleSql =
        'SELECT EXISTS(SELECT 1 FROM $articlesTable WHERE slug = @slug AND deleted_at IS NOT NULL);';

    final hasDeletedArticleResult =
        await connectionPool.query(hasDeletedArticleSql, substitutionValues: {
      'slug': slug,
    });

    var hasDeletedArticle = hasDeletedArticleResult[0][0];

    String sql;
    if (hasDeletedArticle) {
      sql =
          'UPDATE $articlesTable SET deleted_at = NULL, updated_at = current_timestamp WHERE slug = @slug RETURNING id, created_at, updated_at, deleted_at';
    } else {
      sql =
          'INSERT INTO $articlesTable(author_id, title, description, body, tag_list, slug) VALUES (@authorId, @title, @description, @body, @tagList, @slug) RETURNING id, created_at, updated_at, deleted_at;';
    }

    final result = await connectionPool.query(sql, substitutionValues: {
      'authorId': author.id,
      'title': title,
      'description': description,
      'body': body,
      'tagList': tagList,
      'slug': slug
    });

    final articleRow = result[0];

    final articleId = articleRow[0];
    final createdAt = articleRow[1];
    final updatedAt = articleRow[2];
    final deletedAt = articleRow[3];

    return Article(
        id: articleId,
        authorId: author.id,
        title: title,
        description: description,
        body: body,
        tagList: tagList,
        slug: slug,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<Article?> getArticleById(String articleId) async {
    final sql =
        'SELECT author_id, title, description, body, tag_list, slug, created_at, updated_at, deleted_at FROM $articlesTable WHERE id = @articleId AND deleted_at IS NULL;';

    final result = await connectionPool
        .query(sql, substitutionValues: {'articleId': articleId});

    if (result.isEmpty) {
      return null;
    }

    final articleRow = result[0];

    final authorId = articleRow[0];
    final title = articleRow[1];
    final description = articleRow[2];
    final body = articleRow[3];
    final taglist = articleRow[4];
    final slug = articleRow[5];
    final createdAt = articleRow[6];
    final updatedAt = articleRow[7];
    final deletedAt = articleRow[8];

    return Article(
        id: articleId,
        authorId: authorId,
        title: title,
        description: description,
        body: body,
        tagList: taglist,
        slug: slug,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<Article?> getArticleBySlug(String slug) async {
    final sql =
        'SELECT id FROM $articlesTable WHERE slug = @slug AND deleted_at IS NULL;';

    final result =
        await connectionPool.query(sql, substitutionValues: {'slug': slug});

    if (result.isEmpty) {
      return null;
    }

    final articleId = result[0][0];

    return await getArticleById(articleId);
  }

  Future<List<Article>> listArticles(
      {String? tag,
      String? authorId,
      String? favoritedByUserId,
      int? limit,
      int? offset,
      OrderBy? orderBy}) async {
    var sql =
        'SELECT id, author_id, title, description, body, tag_list, slug, created_at, updated_at, deleted_at FROM $articlesTable a WHERE deleted_at IS NULL';

    if (tag != null) {
      sql = sql + ' AND @tag = ANY (tag_list)';
    }

    if (authorId != null) {
      final author = await usersService.getUserById(authorId);

      if (author == null) {
        throw NotFoundException(message: 'Author not found');
      }

      sql = sql + ' AND author_id = @authorId';
    }

    if (favoritedByUserId != null) {
      final user = await usersService.getUserById(favoritedByUserId);

      if (user == null) {
        throw NotFoundException(message: 'User not found');
      }

      sql = sql +
          ' AND EXISTS (SELECT 1 FROM $favoritesTable f WHERE a.id = f.article_id AND f.user_id = @favoritedByUserId)';
    }

    // See https://www.postgresql.org/docs/current/queries-limit.html
    final defaultOrderBy = OrderBy(property: 'created_at', order: Order.desc);

    if (orderBy != null) {
      final columns = [
        'id',
        'author_id',
        'title',
        'description',
        'body',
        'tag_list',
        'slug',
        'created_at',
        'updated_at',
        'deleted_at'
      ];

      if (!columns.contains(orderBy.property)) {
        throw ArgumentException(
            message: 'Invalid orderBy. Must be one of ${columns.join(", ")}',
            parameterName: 'orderBy');
      }
    } else {
      orderBy = defaultOrderBy;
    }

    sql = sql + ' ORDER BY ${orderBy.property} ${orderBy.order.name}';

    if (limit != null) {
      if (limit < 0) {
        throw ArgumentException(
            message: 'limit must be positive', parameterName: 'limit');
      }

      sql = sql + ' LIMIT $limit';
    }

    if (offset != null) {
      if (offset < 0) {
        throw ArgumentException(
            message: 'offset must be positive', parameterName: 'offset');
      }

      sql = sql + ' OFFSET $offset';
    }

    sql = sql + ';';

    final result = await connectionPool.query(sql, substitutionValues: {
      'tag': tag,
      'authorId': authorId,
      'favoritedByUserId': favoritedByUserId,
    });

    final articles = <Article>[];

    for (final row in result) {
      final articleId = row[0];
      final authorId = row[1];
      final title = row[2];
      final description = row[3];
      final body = row[4];
      final tagList = row[5];
      final slug = row[6];
      final createdAt = row[7];
      final updatedAt = row[8];
      final deletedAt = row[9];

      final article = Article(
          id: articleId,
          authorId: authorId,
          title: title,
          description: description,
          body: body,
          tagList: tagList,
          slug: slug,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt);

      articles.add(article);
    }

    return articles;
  }

  Future<Article> updateArticleById(String articleId,
      {String? title,
      String? description,
      String? body,
      List<String>? tagList}) async {
    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article does not exist');
    }

    final initialSql = 'UPDATE $articlesTable';

    var sql = initialSql;

    var slug = article.slug;

    if (title != null && title != article.title) {
      _validateTitleOrThrow(title);

      final author = await usersService.getUserById(article.authorId);

      if (author == null) {
        throw StateError('Author not found');
      }

      slug = _makeSlug(author.username, title);

      await _validateSlugOrThrow(slug);

      if (sql == initialSql) {
        sql = sql + ' SET title = @title, slug = @slug';
      } else {
        sql = sql + ', title = @title, slug = @slug';
      }
    }

    if (description != null && description != article.description) {
      _validateDescriptionOrThrow(description);

      if (sql == initialSql) {
        sql = sql + ' SET description = @description';
      } else {
        sql = sql + ', description = @description';
      }
    }

    if (body != null && body != article.body) {
      _validateBodyOrThrow(body);

      if (sql == initialSql) {
        sql = sql + " SET body = @body";
      } else {
        sql = sql + ", body = @body";
      }
    }

    if (tagList != null) {
      if (sql == initialSql) {
        sql = sql + " SET tag_list = @tagList";
      } else {
        sql = sql + ", tag_list = @tagList";
      }
    }

    if (sql != initialSql) {
      sql = sql + ', updated_at = current_timestamp';
      sql = sql + ' WHERE id = @articleId;';

      await connectionPool.query(sql, substitutionValues: {
        'articleId': article.id,
        'title': title,
        'slug': slug,
        'description': description,
        'body': body,
        'tagList': tagList
      });
    }

    final updatedArticle = await getArticleById(article.id);

    if (updatedArticle == null) {
      throw AssertionError(
          "Article cannot be null at this point. ArticleId: ${article.id}");
    }

    return updatedArticle;
  }

  Future deleteArticleBySlug(String slug) async {
    final article = await getArticleBySlug(slug);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final sql =
        'UPDATE $articlesTable SET deleted_at = current_timestamp WHERE id = @articleId;';

    await connectionPool
        .query(sql, substitutionValues: {'articleId': article.id});
  }

  Future<List<String>> listTags() async {
    final sql =
        'SELECT array_agg(t) FROM (SELECT DISTINCT(unnest(tag_list)) as tags FROM articles a WHERE deleted_at IS null ORDER BY tags) as dt(t);';

    final result = await connectionPool.query(sql);

    if (result.isEmpty) {
      return [];
    }

    return result[0][0] ?? [];
  }

  Future<Favorite> createFavorite(
      {required String userId, required String articleId}) async {
    final user = await usersService.getUserById(userId);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final existingFavorite = await getFavoriteUserIdAndArticleId(
        userId: user.id, articleId: article.id);

    if (existingFavorite != null) {
      return existingFavorite;
    }

    final hasDeletedFavoriteSql =
        'SELECT EXISTS (SELECT 1 FROM $favoritesTable WHERE user_id = @userId AND article_id = @articleId AND deleted_at IS NOT NULL);';

    final hasDeletedFavoriteResult = await connectionPool.query(
        hasDeletedFavoriteSql,
        substitutionValues: {'userId': user.id, 'articleId': article.id});

    final hasDeletedFavorite = hasDeletedFavoriteResult[0][0];

    String sql;
    if (hasDeletedFavorite) {
      sql =
          'UPDATE $favoritesTable SET deleted_at = NULL, updated_at = current_timestamp WHERE user_id = @userId AND article_id = @articleId RETURNING id, created_at, updated_at, deleted_at;';
    } else {
      sql =
          'INSERT INTO $favoritesTable(user_id, article_id) VALUES(@userId, @articleId) RETURNING id, created_at, updated_at, deleted_at;';
    }

    final result = await connectionPool.query(sql,
        substitutionValues: {'userId': user.id, 'articleId': article.id});

    final favoriteRow = result[0];

    final favoriteId = favoriteRow[0];
    final createdAt = favoriteRow[1];
    final updatedAt = favoriteRow[2];
    final deletedAt = favoriteRow[3];

    return Favorite(
        id: favoriteId,
        userId: user.id,
        articleId: article.id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<Favorite?> getFavoriteById(String favoriteId) async {
    final sql =
        'SELECT user_id, article_id, created_at, updated_at, deleted_at FROM $favoritesTable WHERE id = @favoriteId AND deleted_at IS NULL;';

    final result = await connectionPool
        .query(sql, substitutionValues: {'favoriteId': favoriteId});

    final favoriteRow = result[0];

    final userId = favoriteRow[0];
    final articleId = favoriteRow[1];
    final createdAt = favoriteRow[2];
    final updatedAt = favoriteRow[3];
    final deletedAt = favoriteRow[4];

    return Favorite(
        id: favoriteId,
        userId: userId,
        articleId: articleId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<Favorite?> getFavoriteUserIdAndArticleId(
      {required String userId, required String articleId}) async {
    final user = await usersService.getUserById(userId);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final sql =
        'SELECT id FROM $favoritesTable WHERE user_id = @userId AND article_id = @articleId AND deleted_at IS NULL';

    final result = await connectionPool.query(sql,
        substitutionValues: {'userId': user.id, 'articleId': article.id});

    if (result.isEmpty) {
      return null;
    }

    final favoriteId = result[0][0];

    return await getFavoriteById(favoriteId);
  }

  Future<List<Favorite>> listFavorites(String articleId) async {
    final sql =
        'SELECT id, user_id, created_at, updated_at, deleted_at FROM $favoritesTable WHERE article_id = @articleId AND deleted_at IS NULL;';

    final result = await connectionPool
        .query(sql, substitutionValues: {'articleId': articleId});

    final favorites = <Favorite>[];

    for (final row in result) {
      final favoriteId = row[0];
      final userId = row[1];
      final createdAt = row[2];
      final updatedAt = row[3];
      final deletedAt = row[4];

      final favorite = Favorite(
          id: favoriteId,
          userId: userId,
          articleId: articleId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt);

      favorites.add(favorite);
    }

    return favorites;
  }

  Future<int> getFavoritesCount(String articleId) async {
    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final sql =
        'SELECT COUNT(*) FROM $favoritesTable WHERE article_id = @articleId AND deleted_at IS NULL;';

    final result = await connectionPool
        .query(sql, substitutionValues: {'articleId': article.id});

    return result[0][0];
  }

  Future deleteFavoriteById(String favoriteId) async {
    final favorite = await getFavoriteById(favoriteId);

    if (favorite == null) {
      throw NotFoundException(message: 'Favorite not found');
    }

    final sql =
        'UPDATE $favoritesTable SET deleted_at = current_timestamp WHERE id = @favoriteId;';

    await connectionPool
        .query(sql, substitutionValues: {'favoriteId': favoriteId});
  }

  Future deleteFavoriteByUserIdAndArticleId(
      {required String userId, required String articleId}) async {
    final user = await usersService.getUserById(userId);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final sql =
        'SELECT id FROM $favoritesTable WHERE user_id = @userId AND article_id = @articleId AND deleted_at IS NULL;';

    final result = await connectionPool.query(sql,
        substitutionValues: {'userId': user.id, 'articleId': article.id});

    if (result.isEmpty) {
      return;
    }

    final favoriteId = result[0][0];

    await deleteFavoriteById(favoriteId);
  }

  Future<bool> isFavorited(
      {required String userId, required String articleId}) async {
    final user = await usersService.getUserById(userId);

    if (user == null) {
      throw NotFoundException(message: 'User not found');
    }

    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    final sql =
        'SELECT EXISTS(SELECT 1 FROM $favoritesTable WHERE user_id = @userId AND article_id = @articleId AND deleted_at IS NULL);';

    final result = await connectionPool.query(sql,
        substitutionValues: {'userId': user.id, 'articleId': article.id});

    return result[0][0];
  }

  Future<Comment> createComment(
      {required String authorId,
      required String articleId,
      required String body}) async {
    final author = await usersService.getUserById(authorId);

    if (author == null) {
      throw NotFoundException(message: 'Author not found');
    }

    final article = await getArticleById(articleId);

    if (article == null) {
      throw NotFoundException(message: 'Article not found');
    }

    _validateBodyOrThrow(body);

    final sql =
        'INSERT INTO $commentsTable(author_id, article_id, body) VALUES (@authorId, @articleId, @body) RETURNING id, created_at, updated_at, deleted_at';

    final result = await connectionPool.query(sql, substitutionValues: {
      'authorId': author.id,
      'articleId': article.id,
      'body': body
    });

    final commentRow = result[0];

    final commentId = commentRow[0];
    final createdAt = commentRow[1];
    final updatedAt = commentRow[2];
    final deletedAt = commentRow[3];

    return Comment(
        id: commentId,
        authorId: author.id,
        articleId: article.id,
        body: body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<Comment?> getCommentById(String commentId) async {
    var sql =
        'SELECT author_id, article_id, body, created_at, updated_at, deleted_at FROM $commentsTable WHERE id = @commentId AND deleted_at IS NULL';

    final result = await connectionPool
        .query(sql, substitutionValues: {'commentId': commentId});

    if (result.isEmpty) {
      return null;
    }

    final commentRow = result[0];

    final authorId = commentRow[0];
    final articleId = commentRow[1];
    final body = commentRow[2];
    final createdAt = commentRow[3];
    final updatedAt = commentRow[4];
    final deletedAt = commentRow[5];

    return Comment(
        id: commentId,
        authorId: authorId,
        articleId: articleId,
        body: body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt);
  }

  Future<List<Comment>> listComments({String? articleId}) async {
    var sql =
        'SELECT id, author_id, article_id, body, created_at, updated_at, deleted_at FROM $commentsTable WHERE deleted_at IS NULL';

    if (articleId != null) {
      final article = await getArticleById(articleId);

      if (article == null) {
        throw NotFoundException(message: 'Article not found');
      }

      sql = sql + ' AND article_id = @articleId';
    }

    // Default ordering
    sql = sql + ' ORDER BY created_at';

    final result = await connectionPool
        .query(sql, substitutionValues: {'articleId': articleId});

    final comments = <Comment>[];

    for (final row in result) {
      final commentId = row[0];
      final authorId = row[1];
      final articleId = row[2];
      final body = row[3];
      final createdAt = row[4];
      final updatedAt = row[5];
      final deletedAt = row[6];

      final comment = Comment(
          id: commentId,
          authorId: authorId,
          articleId: articleId,
          body: body,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt);

      comments.add(comment);
    }

    return comments;
  }

  Future deleteCommentById(String commentId) async {
    final comment = await getCommentById(commentId);

    if (comment == null) {
      throw NotFoundException(message: 'Comment not found');
    }

    final sql =
        'UPDATE $commentsTable SET deleted_at = current_timestamp WHERE id = @commentId;';

    await connectionPool
        .query(sql, substitutionValues: {'commentId': commentId});
  }

  void _validateTitleOrThrow(String title) {
    if (title.trim().isEmpty) {
      throw ArgumentException(
          message: 'title cannot be blank', parameterName: 'title');
    }
  }

  void _validateDescriptionOrThrow(String description) {
    if (description.trim().isEmpty) {
      throw ArgumentException(
          message: 'description cannot be blank', parameterName: 'description');
    }
  }

  void _validateBodyOrThrow(String body) {
    if (body.trim().isEmpty) {
      throw ArgumentException(
          message: 'body cannot be blank', parameterName: 'body');
    }
  }

  Future _validateSlugOrThrow(String slug) async {
    final existingArticle = await getArticleBySlug(slug);

    if (existingArticle != null) {
      throw AlreadyExistsException(message: 'Article already exists');
    }
  }

  String _makeSlug(String username, String title) {
    return slugify(username + ' ' + title);
  }
}
