import 'dart:convert';

import 'package:flick/features/discovery/discovery_http.dart';
import 'package:flick/features/discovery/discovery_sources.dart';
import 'package:flick/features/discovery/lastwave_signing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('LastWave signature matches the published path-only HMAC vectors', () {
    const secret =
        '36d96a751b12ee481c281a8a8e64c482d0c1634a22061ab72f40175017818b85';
    final url = Uri.parse('https://addons.example/a/abc123/search?q=kesariya');
    final signed = lastWaveHeaders(
      url,
      intent: 'stream',
      epochSeconds: 1700000000,
      signingKey: secret,
    );
    expect(signed['X-LW-TS'], '1700000000');
    expect(signed['X-LW-Intent'], 'stream');
    expect(
      signed['X-LW-Sign'],
      'cc90954e083bd632ba915ba56f748f3b44320fc063ee8b69a8880406f1317adb',
    );
    expect(
      lastWaveHeaders(
        Uri.parse('https://addons.example/a/abc123/search?q=other'),
        epochSeconds: 1700000000,
        signingKey: secret,
      )['X-LW-Sign'],
      signed['X-LW-Sign'],
    );
    expect(
      lastWaveHeaders(Uri.parse('https://addons.example/search')),
      isEmpty,
    );
  });

  test('signed manifest, search, stream and download preserve token path', () async {
    final calls = <http.Request>[];
    final client = MockClient((request) async {
      calls.add(request);
      final path = request.url.path;
      if (path.endsWith('/manifest.json')) {
        return http.Response(jsonEncode({
          'id': 'lastwave-fixture',
          'name': 'LastWave Test',
          'resources': ['search', 'stream'],
        }), 200);
      }
      if (path.endsWith('/search')) {
        return http.Response(jsonEncode({
          'tracks': [
            {'id': 'track-1', 'title': 'Track', 'artist': 'Artist'}
          ],
        }), 200);
      }
      return http.Response(jsonEncode({
        'data': {
          'directUrl': 'https://cdn.example/track.flac',
          'format': 'flac',
          'quality': 'LOSSLESS',
        },
      }), 200);
    });
    addTearDown(client.close);
    final addon = DiscoveryAddon(
      DiscoveryHttp(client),
      endpoint: 'https://addons.example/a/abc123',
      configId: 'lastwave',
      exactManifestUrl:
          Uri.parse('https://addons.example/a/abc123/manifest.json'),
    );

    final health = await addon.health();
    expect(health.name, 'LastWave Test');
    final tracks = await addon.search('Track');
    expect(tracks, hasLength(1));
    final playback = await addon.resolve(tracks.single);
    expect(playback.url.toString(), 'https://cdn.example/track.flac');
    final download = await addon.resolve(tracks.single, forDownload: true);
    expect(download.url, playback.url);

    expect(
      calls.map((r) => r.url.path),
      [
        '/a/abc123/manifest.json',
        '/a/abc123/search',
        '/a/abc123/stream/track-1',
        '/a/abc123/manifest.json',
        '/a/abc123/stream/track-1',
      ],
    );
    expect(
      calls.map((r) => r.headers['X-LW-Intent']),
      [null, 'stream', 'stream', null, 'download'],
    );
    for (final request in calls) {
      expect(request.headers['X-LW-Sign'], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(request.headers['X-LW-TS'], matches(RegExp(r'^\d{10}$')));
    }
  });

  test('ordinary add-ons do not get LastWave signature headers', () async {
    final client = MockClient((request) async {
      expect(request.headers['X-LW-Sign'], isNull);
      expect(request.headers['X-LW-TS'], isNull);
      return http.Response(jsonEncode({
        'tracks': [
          {'id': '1', 'title': 'Track', 'artist': 'Artist'}
        ],
      }), 200);
    });
    addTearDown(client.close);
    final addon = DiscoveryAddon(
      DiscoveryHttp(client),
      endpoint: 'https://addon.example/library',
    );
    expect(await addon.search('Track'), hasLength(1));
  });

  test('outer stream security flags cannot be overwritten by data wrapper', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    addTearDown(client.close);
    final addon = DiscoveryAddon(
      DiscoveryHttp(client),
      endpoint: 'https://addons.example/a/abc123',
    );
    expect(
      () => addon.parseStream({
        'drm': 'widevine',
        'data': {'url': 'https://cdn.example/track.flac', 'drm': false},
      }),
      throwsA(isA<Exception>()),
    );
  });
}
