import 'package:dart_shelf_realworld_example_app/src/articles/dtos/comment_dto.dart';

class MultipleCommentsDto {
  final List<CommentDto> comments;

  MultipleCommentsDto({required this.comments});

  MultipleCommentsDto.fromJson(Map<String, dynamic> json)
      : comments = List.from(json['comments'])
            .map((c) => CommentDto.fromJson(c))
            .toList();

  Map<String, dynamic> toJson() => {
        'comments': comments.map((a) => a.toJson()).toList(),
      };
}
