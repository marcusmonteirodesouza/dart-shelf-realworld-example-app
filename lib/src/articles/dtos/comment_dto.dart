import 'package:dart_shelf_realworld_example_app/src/profiles/dtos/profile_dto.dart';

class CommentDto {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String body;
  final ProfileDto author;

  CommentDto(
      {required this.id,
      required this.createdAt,
      required this.updatedAt,
      required this.body,
      required this.author});

  CommentDto.fromJson(Map<String, dynamic> json)
      : id = json['comment']['id'],
        createdAt = DateTime.parse(json['comment']['createdAt']),
        updatedAt = DateTime.parse(json['comment']['updatedAt']),
        body = json['comment']['body'],
        author = ProfileDto.fromJson(json['comment']['author']);

  Map<String, dynamic> toJson() => {
        'comment': {
          'id': id,
          'createdAt': createdAt.toIso8601String(),
          'updatedAt': updatedAt.toIso8601String(),
          'body': body,
          'author': author.toJson()
        }
      };
}
