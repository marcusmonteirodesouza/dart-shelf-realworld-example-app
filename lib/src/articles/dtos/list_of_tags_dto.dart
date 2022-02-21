class ListOfTagsDto {
  final List<String> tags;

  ListOfTagsDto({required this.tags});

  ListOfTagsDto.fromJson(Map<String, dynamic> json)
      : tags = List.from(json['tags']);

  Map<String, dynamic> toJson() => {
        'tags': tags,
      };
}
