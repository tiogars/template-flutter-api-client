import 'dart:convert';

import 'package:domain_template_client/auth_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const user = {
    'id': 1,
    'username': 'admin',
    'enabled': true,
    'roles': [
      {'id': 1, 'code': 'ADMIN', 'label': 'Administrator'},
    ],
    'createdDate': '2026-01-01T00:00:00Z',
    'lastModifiedDate': '2026-01-01T00:00:00Z',
  };

  test('logs in and decodes the authenticated user', () async {
    late http.Request captured;
    final client = AuthClient(
      baseUri: Uri.parse('https://api.example.test'),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'token': 'jwt-token',
            'tokenType': 'Bearer',
            'expiresAt': '2026-01-01T01:00:00Z',
            'user': user,
          }),
          200,
        );
      }),
    );

    final response = await client.login('admin', 'secret');

    expect(captured.url.path, '/api/v1/auth/login');
    expect(jsonDecode(captured.body), {
      'username': 'admin',
      'password': 'secret',
    });
    expect(response.token, 'jwt-token');
    expect(response.user.hasRole('ADMIN'), isTrue);
  });

  test('sends the bearer token when reading the current user', () async {
    late http.Request captured;
    final client = AuthClient(
      baseUri: Uri.parse('https://api.example.test'),
      accessTokenProvider: () => 'jwt-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode(user), 200);
      }),
    );

    final currentUser = await client.me();

    expect(captured.url.path, '/api/v1/auth/me');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(currentUser.username, 'admin');
  });
}
