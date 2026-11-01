import 'dart:convert';

import 'package:http/http.dart' as http;

import 'task_client.dart';

abstract interface class JsonRequest {
  Map<String, Object?> toJson();
}

class ResourceClient<T, C extends JsonRequest, U extends JsonRequest> {
  ResourceClient({
    required Uri baseUri,
    required String resource,
    required T Function(Map<String, Object?>) fromJson,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
  }) : _baseUri = baseUri,
       _path = '/api/v1/$resource',
       _fromJson = fromJson,
       _http = httpClient ?? http.Client(),
       _accessTokenProvider = accessTokenProvider;

  final Uri _baseUri;
  final String _path;
  final T Function(Map<String, Object?>) _fromJson;
  final http.Client _http;
  final String? Function()? _accessTokenProvider;

  Uri _uri([int? id]) =>
      _baseUri.replace(path: id == null ? _path : '$_path/$id', query: null);

  Map<String, String> get _headers {
    final token = _accessTokenProvider?.call();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty)
        'Authorization': ['Bearer', token].join(' '),
    };
  }

  void _check(http.Response response, int expected) {
    if (response.statusCode != expected) {
      throw TaskException(
        expectedStatus: expected,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  T _decode(http.Response response, int expected) {
    _check(response, expected);
    return _fromJson(
      Map<String, Object?>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<List<T>> findAll() async {
    final response = await _http.get(_uri(), headers: _headers);
    _check(response, 200);
    return (jsonDecode(response.body) as List<dynamic>)
        .map((value) => _fromJson(Map<String, Object?>.from(value as Map)))
        .toList();
  }

  Future<T> findById(int id) async =>
      _decode(await _http.get(_uri(id), headers: _headers), 200);

  Future<T> create(C request) async => _decode(
    await _http.post(_uri(), headers: _headers, body: jsonEncode(request.toJson())),
    201,
  );

  Future<T> update(int id, U request) async => _decode(
    await _http.put(
      _uri(id),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    ),
    200,
  );

  Future<void> delete(int id) async =>
      _check(await _http.delete(_uri(id), headers: _headers), 204);
}

class Category {
  const Category({
    required this.id,
    required this.code,
    required this.label,
    this.description,
    required this.createdDate,
    required this.lastModifiedDate,
    this.createdBy,
    this.lastModifiedBy,
  });

  final int id;
  final String code;
  final String label;
  final String? description;
  final DateTime createdDate;
  final DateTime lastModifiedDate;
  final String? createdBy;
  final String? lastModifiedBy;

  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    'label': label,
    'description': description,
    'createdDate': createdDate.toUtc().toIso8601String(),
    'lastModifiedDate': lastModifiedDate.toUtc().toIso8601String(),
    'createdBy': createdBy,
    'lastModifiedBy': lastModifiedBy,
  };
}
