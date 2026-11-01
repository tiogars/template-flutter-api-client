import 'dart:convert';

import 'package:domain_template_client/task_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const defaults = {
    'status': 'TODO',
    'priority': 'NORMAL',
    'dueDate': null,
    'assignedTo': null,
    'tagIds': <int>[],
    'nomenclatureId': null,
  };
  const baseUrl = 'https://api.example.test';
  const templateJson =
      '{"id":42,"code":"CUSTOMER","label":"Customer","description":"Example",'
      '"createdDate":"2026-08-30T12:00:00Z",'
      '"lastModifiedDate":"2026-08-30T13:00:00Z",'
      '"createdBy":"creator","lastModifiedBy":"editor"}';

  group('serialization', () {
    test('serializes and deserializes a Task', () {
      final template = Task.fromJson(
        jsonDecode(templateJson) as Map<String, Object?>,
      );

      expect(template.id, 42);
      expect(template.code, 'CUSTOMER');
      expect(template.description, 'Example');
      expect(template.createdDate, DateTime.parse('2026-08-30T12:00:00Z'));
      expect(template.createdBy, 'creator');
      expect(template.lastModifiedBy, 'editor');
      expect(template.toJson(), {
        ...defaults,
        'id': 42,
        'code': 'CUSTOMER',
        'label': 'Customer',
        'description': 'Example',
        'createdDate': '2026-08-30T12:00:00.000Z',
        'lastModifiedDate': '2026-08-30T13:00:00.000Z',
        'createdBy': 'creator',
        'lastModifiedBy': 'editor',
      });
    });

    test('accepts older responses without audit actors', () {
      final json = jsonDecode(templateJson) as Map<String, Object?>;
      json.remove('createdBy');
      json.remove('lastModifiedBy');

      final template = Task.fromJson(json);

      expect(template.createdBy, isNull);
      expect(template.lastModifiedBy, isNull);
    });

    test('serializes create and update requests', () {
      expect(
        const CreateTaskRequest(
          code: 'CUSTOMER',
          label: 'Customer',
          description: null,
        ).toJson(),
        {...defaults, 'code': 'CUSTOMER', 'label': 'Customer', 'description': null},
      );
      expect(
        const UpdateTaskRequest(
          label: 'Customers',
          description: 'Updated',
        ).toJson(),
        {...defaults, 'label': 'Customers', 'description': 'Updated'},
      );
    });

    test('round trips task fields and writes date-only requests', () {
      final json = jsonDecode(templateJson) as Map<String, Object?>;
      json.addAll({
        'status': 'IN_PROGRESS', 'priority': 'URGENT',
        'dueDate': '2026-10-15', 'assignedTo': 'alice',
        'tagIds': [2, 3], 'nomenclatureId': 4,
      });
      final task = Task.fromJson(json);
      expect(task.status, TaskStatus.inProgress);
      expect(task.priority, TaskPriority.urgent);
      expect(task.dueDate, DateTime(2026, 10, 15));
      expect(task.toJson()['tagIds'], [2, 3]);
      expect(task.toJson()['nomenclatureId'], 4);
      expect(task.toJson()['dueDate'], '2026-10-15');
      final request = UpdateTaskRequest(
        label: 'Updated', status: task.status, priority: task.priority,
        dueDate: task.dueDate, assignedTo: task.assignedTo,
        tagIds: task.tagIds, nomenclatureId: task.nomenclatureId,
      );
      expect(request.toJson(), {
        'label': 'Updated', 'description': null,
        'status': 'IN_PROGRESS', 'priority': 'URGENT',
        'dueDate': '2026-10-15', 'assignedTo': 'alice',
        'tagIds': [2, 3], 'nomenclatureId': 4,
      });
      expect(request.toJson().containsKey('code'), isFalse);
      expect(TaskStatus.values.map(taskStatusToJson),
          ['TODO', 'IN_PROGRESS', 'DONE', 'CANCELLED']);
      expect(TaskPriority.values.map(taskPriorityToJson),
          ['LOW', 'NORMAL', 'HIGH', 'URGENT']);
    });
  });

  group('TaskClient', () {
    test('calls list and find routes', () async {
      final requests = <http.Request>[];
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((request) async {
          requests.add(request);
          return request.url.path.endsWith('/42')
              ? http.Response(templateJson, 200)
              : http.Response('[$templateJson]', 200);
        }),
      );

      final templates = await client.findAll();
      final template = await client.findById(42);

      expect(templates.single.id, 42);
      expect(template.label, 'Customer');
      expect(requests.map((request) => request.method), ['GET', 'GET']);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/task',
        '/api/v1/task/42',
      ]);
    });

    test('adds the configured bearer token', () async {
      late http.Request captured;
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        accessTokenProvider: () => 'jwt-token',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('[$templateJson]', 200);
        }),
      );

      await client.findAll();

      expect(captured.headers['authorization'], 'Bearer jwt-token');
    });

    test('calls create, update, and delete routes', () async {
      final requests = <http.Request>[];
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') {
            return http.Response('', 204);
          }
          return http.Response(
            templateJson,
            request.method == 'POST' ? 201 : 200,
          );
        }),
      );

      await client.create(
        const CreateTaskRequest(
          code: 'CUSTOMER',
          label: 'Customer',
          description: 'Example',
        ),
      );
      await client.update(
        42,
        const UpdateTaskRequest(
          label: 'Customers',
          description: null,
        ),
      );
      await client.delete(42);

      expect(
          requests.map((request) => request.method), ['POST', 'PUT', 'DELETE']);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/task',
        '/api/v1/task/42',
        '/api/v1/task/42',
      ]);
      expect(jsonDecode(requests[0].body), {
        ...defaults,
        'code': 'CUSTOMER',
        'label': 'Customer',
        'description': 'Example',
      });
      expect(jsonDecode(requests[1].body), {
        ...defaults,
        'label': 'Customers',
        'description': null,
      });
    });

    test('calls seed and JSON import routes', () async {
      final requests = <http.Request>[];
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('[$templateJson]', 201);
        }),
      );
      const values = [
        CreateTaskRequest(code: 'CUSTOMER', label: 'Customer'),
      ];

      expect((await client.seed(values)).single.code, 'CUSTOMER');
      expect((await client.importJson(values)).single.id, 42);

      expect(requests.map((request) => request.url.path), [
        '/api/v1/task/seed',
        '/api/v1/task/import.json',
      ]);
      expect(requests.every((request) => request.method == 'POST'), isTrue);
      expect(jsonDecode(requests.first.body), [
        {...defaults, 'code': 'CUSTOMER', 'label': 'Customer', 'description': null},
      ]);
    });

    test('calls CSV import and both export routes', () async {
      final requests = <http.Request>[];
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('import.csv')) {
            return http.Response('[$templateJson]', 201);
          }
          if (request.url.path.endsWith('export.csv')) {
            return http.Response('code,label\nCUSTOMER,Customer\n', 200);
          }
          return http.Response('[$templateJson]', 200);
        }),
      );

      final imported =
          await client.importCsv('code,label\nCUSTOMER,Customer\n');
      final jsonExport = await client.exportJson();
      final csvExport = await client.exportCsv();

      expect(imported.single.code, 'CUSTOMER');
      expect(jsonExport.single.id, 42);
      expect(csvExport, contains('CUSTOMER,Customer'));
      expect(requests.map((request) => request.url.path), [
        '/api/v1/task/import.csv',
        '/api/v1/task/export.json',
        '/api/v1/task/export.csv',
      ]);
      expect(requests.first.headers['content-type'], 'text/csv; charset=utf-8');
    });

    test('seed and JSON import round trip scheduling and taxonomy fields', () async {
      final requests = <http.Request>[];
      final enriched = {
        ...(jsonDecode(templateJson) as Map<String, Object?>),
        'status': 'DONE',
        'priority': 'HIGH',
        'dueDate': '2026-11-05',
        'assignedTo': 'external-team',
        'tagIds': [10, 11],
        'nomenclatureId': 20,
      };
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode([enriched]), 201);
        }),
      );
      final values = [
        CreateTaskRequest(
          code: 'CUSTOMER',
          label: 'Customer',
          status: TaskStatus.done,
          priority: TaskPriority.high,
          dueDate: DateTime(2026, 11, 5),
          assignedTo: 'external-team',
          tagIds: const [10, 11],
          nomenclatureId: 20,
        ),
      ];
      for (final result in [
        await client.seed(values),
        await client.importJson(values),
      ]) {
        expect(result.single.status, TaskStatus.done);
        expect(result.single.priority, TaskPriority.high);
        expect(taskDateToJson(result.single.dueDate), '2026-11-05');
        expect(result.single.assignedTo, 'external-team');
        expect(result.single.tagIds, [10, 11]);
        expect(result.single.nomenclatureId, 20);
      }
      for (final request in requests) {
        expect(jsonDecode(request.body), [values.single.toJson()]);
      }
    });

    test('throws a typed exception for an unexpected status', () async {
      final client = TaskClient(
        baseUri: Uri.parse(baseUrl),
        httpClient: MockClient((_) async => http.Response('missing', 404)),
      );

      expect(
        () => client.findById(999),
        throwsA(
          isA<TaskException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.responseBody, 'responseBody', 'missing'),
        ),
      );
    });
  });
}
