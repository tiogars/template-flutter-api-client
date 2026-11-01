import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:domain_template_client/nomenclature_client.dart';
import 'package:domain_template_client/tag_client.dart';
import 'package:domain_template_client/task_client.dart';
import 'package:test/test.dart';

void main() {
  final json = <String, Object?>{
    'id': 1, 'code': 'WORK', 'label': 'Work', 'description': 'Category',
    'createdDate': '2026-10-14T10:00:00.000Z',
    'lastModifiedDate': '2026-10-14T11:00:00.000Z',
    'createdBy': 'admin', 'lastModifiedBy': 'editor',
  };

  test('tag and nomenclature preserve audit data and nullable parents', () {
    expect(Tag.fromJson(json).toJson(), json);
    expect(Nomenclature.fromJson(json).toJson(), {...json, 'parentId': null});
    expect(Nomenclature.fromJson({...json, 'parentId': 2}).toJson(),
      {...json, 'parentId': 2});
  });

  test('requests include code only when creating and parent can be cleared', () {
    expect(const CreateTagRequest(code: 'WORK', label: 'Work').toJson(),
      {'code': 'WORK', 'label': 'Work', 'description': null});
    expect(const UpdateTagRequest(label: 'Updated').toJson(),
      {'label': 'Updated', 'description': null});
    expect(const CreateNomenclatureRequest(
      code: 'CHILD', label: 'Child', description: 'Child category', parentId: 1,
    ).toJson(), {
      'code': 'CHILD', 'label': 'Child', 'description': 'Child category', 'parentId': 1,
    });
    expect(const UpdateNomenclatureRequest(label: 'Root').toJson(),
      {'label': 'Root', 'description': null, 'parentId': null});
  });

  for (final resource in ['tag', 'nomenclature']) {
    test('$resource CRUD uses authenticated routes and JSON bodies', () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        final body = {...json, if (resource == 'nomenclature') 'parentId': 2};
        return http.Response(
          jsonEncode(request.method == 'GET' && !request.url.path.endsWith('/1')
              ? [body] : body),
          request.method == 'POST' ? 201 : 200,
        );
      });
      if (resource == 'tag') {
        final client = TagClient(baseUri: Uri.parse('https://example.test'),
          httpClient: mock, accessTokenProvider: () => 'test-token');
        expect((await client.findAll()).single.id, 1);
        expect((await client.findById(1)).code, 'WORK');
        await client.create(const CreateTagRequest(code: 'WORK', label: 'Work'));
        await client.update(1, const UpdateTagRequest(label: 'Updated'));
        await client.delete(1);
      } else {
        final client = NomenclatureClient(baseUri: Uri.parse('https://example.test'),
          httpClient: mock, accessTokenProvider: () => 'test-token');
        expect((await client.findAll()).single.parentId, 2);
        expect((await client.findById(1)).id, 1);
        await client.create(const CreateNomenclatureRequest(
          code: 'WORK', label: 'Work', parentId: 2));
        await client.update(1, const UpdateNomenclatureRequest(label: 'Updated'));
        await client.delete(1);
      }
      expect(requests.map((request) => request.method),
        ['GET', 'GET', 'POST', 'PUT', 'DELETE']);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/$resource', '/api/v1/$resource/1',
        '/api/v1/$resource', '/api/v1/$resource/1', '/api/v1/$resource/1',
      ]);
      for (final request in requests) {
        expect(request.headers['authorization'], ['Bearer', 'test-token'].join(' '));
      }
      expect((jsonDecode(requests[2].body) as Map)['code'], 'WORK');
      expect((jsonDecode(requests[3].body) as Map).containsKey('code'), isFalse);
      if (resource == 'nomenclature') {
        expect((jsonDecode(requests[2].body) as Map)['parentId'], 2);
        expect((jsonDecode(requests[3].body) as Map)['parentId'], isNull);
      }
    });

    test('$resource exposes backend validation errors', () async {
      final mock = MockClient((_) async => http.Response('Referenced category', 409));
      final future = resource == 'tag'
          ? TagClient(baseUri: Uri.parse('https://example.test'), httpClient: mock).delete(1)
          : NomenclatureClient(baseUri: Uri.parse('https://example.test'), httpClient: mock).delete(1);
      await expectLater(future, throwsA(isA<TaskException>()
        .having((error) => error.statusCode, 'status', 409)
        .having((error) => error.responseBody, 'body', 'Referenced category')));
    });
  }
}
