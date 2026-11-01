import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthRole {
  const AuthRole({required this.id, required this.code, required this.label});

  final int id;
  final String code;
  final String label;

  factory AuthRole.fromJson(Map<String, Object?> json) => AuthRole(
        id: json['id'] as int,
        code: json['code'] as String,
        label: json['label'] as String,
      );
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.enabled,
    required this.roles,
  });

  final int id;
  final String username;
  final bool enabled;
  final List<AuthRole> roles;

  bool hasRole(String code) => roles.any((role) => role.code == code);

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
        id: json['id'] as int,
        username: json['username'] as String,
        enabled: json['enabled'] as bool,
        roles: (json['roles'] as List<dynamic>)
            .map(
              (role) => AuthRole.fromJson(
                Map<String, Object?>.from(role as Map),
              ),
            )
            .toList(),
      );
}

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final String tokenType;
  final DateTime expiresAt;
  final AuthUser user;

  factory LoginResponse.fromJson(Map<String, Object?> json) => LoginResponse(
        token: json['token'] as String,
        tokenType: json['tokenType'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        user: AuthUser.fromJson(
          Map<String, Object?>.from(json['user'] as Map),
        ),
      );
}

class AuthClient {
  AuthClient({
    required Uri baseUri,
    http.Client? httpClient,
    String? Function()? accessTokenProvider,
  })  : _baseUri = baseUri,
        _httpClient = httpClient ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  final Uri _baseUri;
  final http.Client _httpClient;
  final String? Function()? _accessTokenProvider;

  Future<LoginResponse> login(String username, String password) async {
    final response = await _httpClient.post(
      _uri('/api/v1/auth/login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({'username': username, 'password': password}),
    );
    _requireStatus(response, 200);
    return LoginResponse.fromJson(
      Map<String, Object?>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<AuthUser> me() async {
    final response = await _httpClient.get(
      _uri('/api/v1/auth/me'),
      headers: _authorizedHeaders(),
    );
    _requireStatus(response, 200);
    return AuthUser.fromJson(
      Map<String, Object?>.from(jsonDecode(response.body) as Map),
    );
  }

  Map<String, String> _authorizedHeaders() {
    final token = _accessTokenProvider?.call();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _requireStatus(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      throw AuthException(
        expectedStatus: expectedStatus,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  Uri _uri(String path) => _baseUri.replace(path: path, query: null);
}

class AuthException implements Exception {
  const AuthException({
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
