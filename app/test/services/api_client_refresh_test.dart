// app/test/services/api_client_refresh_test.dart
// 2026-09-17 13:48 ET: Bo's tablet dropped to the Login screen with no
// server-side rejection. A refresh that cannot be COMPLETED (network,
// timeout, 5xx, 429) must never sign the user out; only a definitive 401 on
// /auth/refresh with no newer token from the background isolate does.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfamily/services/api_client.dart';
import 'package:openfamily/services/background_credential_store.dart';
import 'package:openfamily/services/server_config.dart';
import 'package:openfamily/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ServerConfig.instance.debugReset();
    await ServerConfig.instance.setUrl('http://api.test');
    await TokenStorage.saveTokens(access: 'old-access', refresh: 'old-refresh');
    ApiClient.markSessionActive();
  });

  tearDown(() {
    ApiClient.client = null;
    ApiClient.onSessionExpired = null;
  });

  /// A fake server: /family/members 401s for the old token, 200s for a new one;
  /// /auth/refresh answers as told.
  MockClient server({required http.Response Function() refresh}) => MockClient((http.Request r) async {
        if (r.url.path == '/auth/refresh') return refresh();
        final String auth = r.headers['Authorization'] ?? '';
        if (auth == 'Bearer new-access') return http.Response(jsonEncode(<Object>[]), 200);
        return http.Response('{"error":"unauthenticated"}', 401);
      });

  test('refresh 200: the new pair is stored and the request is retried with it', () async {
    ApiClient.client = server(refresh: () => http.Response(jsonEncode(<String, String>{'access_token': 'new-access', 'refresh_token': 'new-refresh'}), 200));
    bool expired = false;
    ApiClient.onSessionExpired = () => expired = true;
    final dynamic data = await ApiClient.get('/family/members');
    expect(data, isA<List<dynamic>>());
    expect(await TokenStorage.readAccessToken(), 'new-access');
    expect(expired, isFalse);
  });

  for (final (String why, http.Response Function() refresh) in <(String, http.Response Function())>[
    ('502 from a restarting api', () => http.Response('bad gateway', 502)),
    ('429 rate limited', () => http.Response('{"error":"too many requests"}', 429)),
    ('connection refused', () => throw http.ClientException('connection refused')),
  ]) {
    test('refresh $why: the session is KEPT - tokens intact, no sign-out, the one request fails', () async {
      ApiClient.client = server(refresh: refresh);
      bool expired = false;
      ApiClient.onSessionExpired = () => expired = true;
      await expectLater(ApiClient.get('/family/members'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 0)));
      expect(await TokenStorage.readAccessToken(), 'old-access');
      expect(await TokenStorage.readRefreshToken(), 'old-refresh');
      expect(expired, isFalse);
    });
  }

  test('refresh 401 (the refresh token is dead) with nothing newer from the background: tokens cleared, signed out', () async {
    ApiClient.client = server(refresh: () => http.Response('{"error":"invalid refresh token"}', 401));
    bool expired = false;
    ApiClient.onSessionExpired = () => expired = true;
    await expectLater(ApiClient.get('/family/members'), throwsA(isA<SessionExpiredException>()));
    expect(await TokenStorage.readAccessToken(), isNull);
    expect(expired, isTrue);
  });

  test('refresh 401 but the background isolate already rotated the pair: its tokens are used, no sign-out', () async {
    // the background store holds the rotated pair (TokenStorage.syncFromBackgroundStore reads it)
    await BackgroundCredentialStore.sync(apiBaseUrl: 'http://api.test', accessToken: 'new-access', deviceId: 'dev');
    ApiClient.client = server(refresh: () => http.Response('{"error":"invalid refresh token"}', 401));
    bool expired = false;
    ApiClient.onSessionExpired = () => expired = true;
    final dynamic data = await ApiClient.get('/family/members');
    expect(data, isA<List<dynamic>>());
    expect(expired, isFalse);
  });
}
