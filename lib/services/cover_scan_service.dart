import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/title_candidate.dart';

class CoverScanException implements Exception {
  final String message;
  CoverScanException(this.message);
  @override
  String toString() => message;
}

/// Identifies candidate game titles from a photo of a cover/box/cartridge by
/// sending the image to OpenAI's GPT-5 nano vision model and parsing a
/// structured list of `{title, confidence}` guesses.
///
/// This replaces on-device OCR: instead of reading raw text (which struggles
/// with stylised logos and multi-line titles), the model recognises the game
/// and returns the canonical title, so the IGDB search has a much better query.
class CoverScanService {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-5-nano';
  static const _maxCandidates = 6;

  final ImagePicker _picker;
  final http.Client _client;

  CoverScanService({ImagePicker? picker, http.Client? client})
      : _picker = picker ?? ImagePicker(),
        _client = client ?? http.Client();

  String get _apiKey => const String.fromEnvironment('OPENAI_API_KEY');
  String get _orgId => const String.fromEnvironment('OPENAI_ORG_ID');

  /// Picks an image, asks the model to recognise it and returns candidate
  /// titles ordered by the model's confidence (highest first). Returns an
  /// empty list if the user cancels the picker.
  Future<List<TitleCandidate>> scan({bool fromCamera = true}) async {
    final photo = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (photo == null) return [];

    if (_apiKey.isEmpty) {
      throw CoverScanException('Missing OPENAI_API_KEY in .env');
    }

    final bytes = await photo.readAsBytes();
    final mime = _mimeFor(photo.path);
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

    return _recognize(dataUri);
  }

  Future<List<TitleCandidate>> _recognize(String dataUri) async {
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        if (_orgId.isNotEmpty) 'OpenAI-Organization': _orgId,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        // Simple extraction task; keep reasoning minimal for a fast response.
        'reasoning_effort': 'minimal',
        'max_completion_tokens': 2000,
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'game_titles',
            'strict': true,
            'schema': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'titles': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': {
                      'title': {'type': 'string'},
                      'confidence': {
                        'type': 'number',
                        'description': 'Likelihood 0-1 that this is the game.',
                      },
                    },
                    'required': ['title', 'confidence'],
                  },
                },
              },
              'required': ['titles'],
            },
          },
        },
        'messages': [
          {
            'role': 'system',
            'content':
                'You identify videogames from photos of their physical media '
                '(box art, cover, cartridge or disc). Return up to '
                '$_maxCandidates candidate official game titles ordered by '
                'likelihood, each with a confidence between 0 and 1. Use the '
                'visible logo, artwork, platform and any text. Prefer the '
                'canonical official title (omit edition/region suffixes unless '
                'printed prominently). If you cannot identify a specific game, '
                'return your best guesses from the readable text.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'What videogame is this? List candidate titles.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': dataUri, 'detail': 'auto'},
              },
            ],
          },
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw CoverScanException(
          'OpenAI request failed (${res.statusCode}): ${res.body}');
    }

    return _parse(res.body);
  }

  List<TitleCandidate> _parse(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = body['choices'] as List<dynamic>?;
    final content =
        (choices?.firstOrNull as Map<String, dynamic>?)?['message']?['content'];
    if (content is! String || content.isEmpty) return [];

    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final titles = parsed['titles'] as List<dynamic>? ?? [];

    final seen = <String>{};
    final candidates = <TitleCandidate>[];
    for (final item in titles) {
      if (item is! Map<String, dynamic>) continue;
      final candidate = TitleCandidate.fromJson(item);
      if (candidate.title.isEmpty) continue;
      if (!seen.add(candidate.title.toLowerCase())) continue;
      candidates.add(candidate);
    }
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    if (candidates.length > _maxCandidates) {
      candidates.removeRange(_maxCandidates, candidates.length);
    }
    return candidates;
  }

  String _mimeFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
