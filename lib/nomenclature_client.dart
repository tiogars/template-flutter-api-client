import 'package:http/http.dart' as http;

import 'resource_client.dart';
import 'tag_client.dart';

class Nomenclature extends Category {
  const Nomenclature({
    required super.id,
    required super.code,
    required super.label,
    super.description,
    required super.createdDate,
    required super.lastModifiedDate,
    super.createdBy,
    super.lastModifiedBy,
    this.parentId,
  });

  final int? parentId;

  factory Nomenclature.fromJson(Map<String, Object?> json) => Nomenclature(
    id: json['id'] as int,
    code: json['code'] as String,
    label: json['label'] as String,
    description: json['description'] as String?,
    createdDate: DateTime.parse(json['createdDate'] as String),
    lastModifiedDate: DateTime.parse(json['lastModifiedDate'] as String),
    createdBy: json['createdBy'] as String?,
    lastModifiedBy: json['lastModifiedBy'] as String?,
    parentId: json['parentId'] as int?,
  );

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'parentId': parentId};
}

class UpdateNomenclatureRequest extends UpdateTagRequest {
  const UpdateNomenclatureRequest({
    required super.label,
    super.description,
    this.parentId,
  });

  final int? parentId;

  @override
  Map<String, Object?> toJson() => {...super.toJson(), 'parentId': parentId};
}

class CreateNomenclatureRequest extends UpdateNomenclatureRequest {
  const CreateNomenclatureRequest({
    required this.code,
    required super.label,
    super.description,
    super.parentId,
  });

  final String code;

  @override
  Map<String, Object?> toJson() => {'code': code, ...super.toJson()};
}

class NomenclatureClient extends ResourceClient<
    Nomenclature, CreateNomenclatureRequest, UpdateNomenclatureRequest> {
  NomenclatureClient({
    required Uri baseUri,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
  }) : super(
         baseUri: baseUri,
         resource: 'nomenclature',
         fromJson: Nomenclature.fromJson,
         httpClient: httpClient,
         accessTokenProvider: accessTokenProvider,
       );
}
