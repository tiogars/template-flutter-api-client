import 'dart:convert';

import 'package:http/http.dart' as http;

enum TaskStatus { todo, inProgress, done, cancelled }

enum TaskPriority { low, normal, high, urgent }

String taskStatusToJson(TaskStatus status) =>
    const ['TODO', 'IN_PROGRESS', 'DONE', 'CANCELLED'][status.index];

String taskPriorityToJson(TaskPriority priority) =>
    const ['LOW', 'NORMAL', 'HIGH', 'URGENT'][priority.index];

String? taskDateToJson(DateTime? date) => date == null
    ? null
    : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Task {
  const Task({
    required this.id,
    required this.code,
    required this.label,
    required this.description,
    required this.createdDate,
    required this.lastModifiedDate,
    this.createdBy,
    this.lastModifiedBy,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.normal,
    this.dueDate,
    this.assignedTo,
    this.tagIds = const [],
    this.nomenclatureId,
  });

  final int id;
  final String code;
  final String label;
  final String? description;
  final DateTime createdDate;
  final DateTime lastModifiedDate;
  final String? createdBy;
  final String? lastModifiedBy;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? assignedTo;
  final List<int> tagIds;
  final int? nomenclatureId;

  factory Task.fromJson(Map<String, Object?> json) {
    return Task(
      id: json['id'] as int,
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      createdDate: DateTime.parse(json['createdDate'] as String),
      lastModifiedDate: DateTime.parse(json['lastModifiedDate'] as String),
      createdBy: json['createdBy'] as String?,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      status: TaskStatus.values.firstWhere(
        (value) => taskStatusToJson(value) == (json['status'] ?? 'TODO'),
      ),
      priority: TaskPriority.values.firstWhere(
        (value) => taskPriorityToJson(value) == (json['priority'] ?? 'NORMAL'),
      ),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      assignedTo: json['assignedTo'] as String?,
      tagIds: (json['tagIds'] as List<dynamic>? ?? const []).cast<int>(),
      nomenclatureId: json['nomenclatureId'] as int?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'code': code,
        'label': label,
        'description': description,
        'createdDate': createdDate.toUtc().toIso8601String(),
        'lastModifiedDate': lastModifiedDate.toUtc().toIso8601String(),
        'createdBy': createdBy,
        'lastModifiedBy': lastModifiedBy,
        'status': taskStatusToJson(status),
        'priority': taskPriorityToJson(priority),
        'dueDate': taskDateToJson(dueDate),
        'assignedTo': assignedTo,
        'tagIds': tagIds,
        'nomenclatureId': nomenclatureId,
      };
}

class CreateTaskRequest extends UpdateTaskRequest {
  const CreateTaskRequest({
    required this.code,
    required super.label,
    super.description,
    super.status,
    super.priority,
    super.dueDate,
    super.assignedTo,
    super.tagIds,
    super.nomenclatureId,
  });

  final String code;

  @override
  Map<String, Object?> toJson() => {
        'code': code,
        ...super.toJson(),
      };
}

class UpdateTaskRequest {
  const UpdateTaskRequest({
    required this.label,
    this.description,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.normal,
    this.dueDate,
    this.assignedTo,
    this.tagIds = const [],
    this.nomenclatureId,
  });

  final String label;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String? assignedTo;
  final List<int> tagIds;
  final int? nomenclatureId;

  Map<String, Object?> toJson() => {
        'label': label,
        'description': description,
        'status': taskStatusToJson(status),
        'priority': taskPriorityToJson(priority),
        'dueDate': taskDateToJson(dueDate),
        'assignedTo': assignedTo,
        'tagIds': tagIds,
        'nomenclatureId': nomenclatureId,
      };
}

class TaskClient {
  TaskClient({
    required Uri baseUri,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
  })  : _baseUri = baseUri,
        _httpClient = httpClient ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  static const _resourcePath = '/api/v1/task';
  final Uri _baseUri;
  final http.Client _httpClient;
  final String? Function()? _accessTokenProvider;

  Future<List<Task>> findAll() async {
    final response = await _httpClient.get(
      _uri(_resourcePath),
      headers: _headers(),
    );
    return _decodeTasks(response, expectedStatus: 200);
  }

  Future<Task> findById(int id) async {
    final response = await _httpClient.get(
      _uri('$_resourcePath/$id'),
      headers: _headers(),
    );
    return _decodeTask(response, expectedStatus: 200);
  }

  Future<Task> create(CreateTaskRequest request) async {
    final response = await _httpClient.post(
      _uri(_resourcePath),
      headers: _headers(contentType: 'application/json; charset=utf-8'),
      body: jsonEncode(request.toJson()),
    );
    return _decodeTask(response, expectedStatus: 201);
  }

  Future<Task> update(
    int id,
    UpdateTaskRequest request,
  ) async {
    final response = await _httpClient.put(
      _uri('$_resourcePath/$id'),
      headers: _headers(contentType: 'application/json; charset=utf-8'),
      body: jsonEncode(request.toJson()),
    );
    return _decodeTask(response, expectedStatus: 200);
  }

  Future<void> delete(int id) async {
    final response = await _httpClient.delete(
      _uri('$_resourcePath/$id'),
      headers: _headers(),
    );
    _requireStatus(response, 204);
  }

  Future<List<Task>> seed(
    List<CreateTaskRequest> requests,
  ) {
    return _postJsonList('$_resourcePath/seed', requests);
  }

  Future<List<Task>> importJson(
    List<CreateTaskRequest> requests,
  ) {
    return _postJsonList('$_resourcePath/import.json', requests);
  }

  Future<List<Task>> importCsv(String csv) async {
    final response = await _httpClient.post(
      _uri('$_resourcePath/import.csv'),
      headers: _headers(contentType: 'text/csv; charset=utf-8'),
      body: csv,
    );
    return _decodeTasks(response, expectedStatus: 201);
  }

  Future<List<Task>> exportJson() async {
    final response = await _httpClient.get(
      _uri('$_resourcePath/export.json'),
      headers: _headers(),
    );
    return _decodeTasks(response, expectedStatus: 200);
  }

  Future<String> exportCsv() async {
    final response = await _httpClient.get(
      _uri('$_resourcePath/export.csv'),
      headers: _headers(accept: 'text/csv'),
    );
    _requireStatus(response, 200);
    return response.body;
  }

  Future<List<Task>> _postJsonList(
    String path,
    List<CreateTaskRequest> requests,
  ) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(contentType: 'application/json; charset=utf-8'),
      body: jsonEncode(requests.map((request) => request.toJson()).toList()),
    );
    return _decodeTasks(response, expectedStatus: 201);
  }

  Task _decodeTask(
    http.Response response, {
    required int expectedStatus,
  }) {
    _requireStatus(response, expectedStatus);
    return Task.fromJson(
      Map<String, Object?>.from(jsonDecode(response.body) as Map),
    );
  }

  List<Task> _decodeTasks(
    http.Response response, {
    required int expectedStatus,
  }) {
    _requireStatus(response, expectedStatus);
    final values = jsonDecode(response.body) as List<dynamic>;
    return values
        .map(
          (value) => Task.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
        )
        .toList();
  }

  void _requireStatus(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      throw TaskException(
        expectedStatus: expectedStatus,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Uri _uri(String path) => _baseUri.replace(path: path, query: null);

  Map<String, String> _headers({
    String accept = 'application/json',
    String? contentType,
  }) {
    final token = _accessTokenProvider?.call();
    return {
      'Accept': accept,
      if (contentType != null) 'Content-Type': contentType,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}

class TaskException implements Exception {
  const TaskException({
    required this.expectedStatus,
    required this.statusCode,
    required this.responseBody,
  });

  final int expectedStatus;
  final int statusCode;
  final String responseBody;

  @override
  String toString() =>
      'Expected HTTP $expectedStatus but received $statusCode: $responseBody';
}
