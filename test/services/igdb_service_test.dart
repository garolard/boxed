import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgcollection/services/igdb_service.dart';

/// Captures the Apicalypse body IGDB is asked for, so the search filters can be
/// asserted without hitting the network.
class _Recorder {
  String? body;

  http.Client client(String responseJson) => MockClient((request) async {
        if (request.url.host == 'id.twitch.tv') {
          return http.Response(
            jsonEncode({'access_token': 'tok', 'expires_in': 100000}),
            200,
          );
        }
        body = request.body;
        return http.Response(responseJson, 200);
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('searchGames query', () {
    late _Recorder recorder;
    late IgdbService service;

    setUp(() {
      recorder = _Recorder();
      service = IgdbService(client: recorder.client('[]'));
    });

    test('keeps games, DLC and expansions but drops mods and bundles',
        () async {
      await service.searchGames('zelda');

      expect(recorder.body, contains('game_type = (0,1,2,4,8,9,10,11)'));
    });

    test('excludes unreleased entries', () async {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await service.searchGames('zelda');
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(recorder.body, contains('first_release_date != null'));
      final match = RegExp(r'first_release_date < (\d+)')
          .firstMatch(recorder.body!);
      expect(match, isNotNull);
      final cutoff = int.parse(match!.group(1)!);
      expect(cutoff, inInclusiveRange(before, after));
    });

    test('excludes alternate editions and unshipped statuses', () async {
      await service.searchGames('zelda');

      expect(recorder.body, contains('version_parent = null'));
      expect(recorder.body, contains('(status = null | status = (0,5,8))'));
    });

    test('keeps platform and genre filters alongside the base filters',
        () async {
      await service.searchGames('zelda', platformId: 130, genreId: 12);

      expect(recorder.body, contains('platforms = (130)'));
      expect(recorder.body, contains('genres = (12)'));
      expect(recorder.body, contains('game_type = (0,1,2,4,8,9,10,11)'));
    });

    test('applies the base filters even with no platform or genre', () async {
      await service.searchGames('zelda');

      expect(recorder.body, contains('where '));
      expect(recorder.body, isNot(contains('platforms = (')));
    });
  });

  test('gamesByIds is not narrowed by the search filters', () async {
    final recorder = _Recorder();
    final service = IgdbService(client: recorder.client('[]'));

    await service.gamesByIds([1, 2, 3]);

    expect(recorder.body, contains('where id = (1,2,3)'));
    expect(recorder.body, isNot(contains('game_type')));
  });
}
