import 'package:http/http.dart' as http;

import 'resource_client.dart';

class Tag extends Category {
  const Tag({
    required super.id,
    required super.code,
    required super.label,
    super.description,
    required super.createdDate,
    required super.lastModifiedDate,
    super.createdBy,
    super.lastModifiedBy,
  });

  factory Tag.fromJson(Map<String, Object?> json) => Tag(
    id: json['id'] as int,
    code: json['code'] as String,
    label: json['label'] as String,
    description: json['description'] as String?,
    createdDate: DateTime.parse(json['createdDate'] as String),
    lastModifiedDate: DateTime.parse(json['lastModifiedDate'] as String),
    createdBy: json['createdBy'] as String?,
    lastModifiedBy: json['lastModifiedBy'] as String?,
  );
}

class UpdateTagRequest implements JsonRequest {
  const UpdateTagRequest({required this.label, this.description});
  final String label;
  final String? description;

  @override
  Map<String, Object?> toJson() => {
    'label': label,
    'description': description,
  };
}

class CreateTagRequest extends UpdateTagRequest {
  const CreateTagRequest({
    required this.code,
    required super.label,
    super.description,
  });
  final String code;

  @override
  Map<String, Object?> toJson() => {'code': code, ...super.toJson()};
}

class TagClient
    extends ResourceClient<Tag, CreateTagRequest, UpdateTagRequest> {
  TagClient({
    required Uri baseUri,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
  }) : super(
         baseUri: baseUri,
         resource: 'tag',
         fromJson: Tag.fromJson,
         httpClient: httpClient,
         accessTokenProvider: accessTokenProvider,
       );
}
