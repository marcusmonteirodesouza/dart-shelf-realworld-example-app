import 'package:dart_shelf_realworld_example_app/src/common/model/base_entity.dart';

class Comment extends BaseEntity {
  final String authorId;
  final String articleId;
  final String body;

  Comment(
      {required String id,
      required this.authorId,
      required this.articleId,
      required this.body,
      required DateTime createdAt,
      required DateTime updatedAt,
      required DateTime? deletedAt})
      : super(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt);
}
