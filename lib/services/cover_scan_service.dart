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
/// posting the image to the cover-scan worker (`worker/`), which calls OpenAI's
/// GPT-5 nano vision model and returns a list of `{title, confidence}` guesses.
///
/// The app deliberately holds no OpenAI credentials: the key lives only in the
/// worker's secrets, so it cannot be extracted from the shipped binary.
///
/// This replaces on-device OCR: instead of reading raw text (which struggles
/// with stylised logos and multi-line titles), the model recognises the game
/// and returns the canonical title, so the IGDB search has a much better query.
class CoverScanService {
  static const _maxCandidates = 6;

  /// Longest edge, in pixels, of the image we upload.
  ///
  /// The vision model resizes anything larger to fit a 768px short edge
  /// before it looks at it, so pixels above this are encoded, uploaded and
  /// then discarded server-side. Capping here cuts the request body several
  /// times over, which shortens the upload — and on cellular the radio
  /// staying in its high-power state is the expensive part of a scan.
  ///
  /// Do not lower this much further: game logos are stylised, and once the
  /// title stops being legible in the upload the model starts guessing.
  static const _maxImageEdge = 768.0;

  /// JPEG quality for the upload. Cover art is flat, high-contrast artwork,
  /// which survives this comfortably.
  static const _imageQuality = 80;

  final ImagePicker _picker;
  final http.Client _client;
  final bool _ownsClient;
  final String _endpoint;
  final String _appToken;

  /// The endpoint and token default to the compile-time dart-defines; they are
  /// constructor parameters so tests can drive the upload path offline.
  CoverScanService({
    ImagePicker? picker,
    http.Client? client,
    String endpoint = const String.fromEnvironment('COVER_SCAN_ENDPOINT'),
    String appToken = const String.fromEnvironment('COVER_SCAN_TOKEN'),
  })  : _picker = picker ?? ImagePicker(),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        // Initializing formals can't be used here: named parameters may not
        // be private, and these fields are.
        // ignore: prefer_initializing_formals
        _endpoint = endpoint,
        // ignore: prefer_initializing_formals
        _appToken = appToken;

  /// Closes the HTTP client, releasing its keep-alive connection. Only closes
  /// a client this service created — an injected one stays the caller's.
  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// Picks an image, asks the worker to recognise it and returns candidate
  /// titles ordered by confidence (highest first). Returns an empty list if
  /// the user cancels the picker.
  Future<List<TitleCandidate>> scan({bool fromCamera = true}) async {
    // Both bounds are set so the *longest* edge is capped. With maxWidth
    // alone a portrait photo stayed full-height, which is most of them.
    final photo = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxImageEdge,
      maxHeight: _maxImageEdge,
      imageQuality: _imageQuality,
    );
    if (photo == null) return [];

    if (_endpoint.isEmpty) {
      throw CoverScanException(
        'Missing COVER_SCAN_ENDPOINT (pass it with --dart-define)',
      );
    }

    final bytes = await photo.readAsBytes();
    return _recognize(bytes, _mimeFor(photo.path));
  }

  Future<List<TitleCandidate>> _recognize(List<int> bytes, String mime) async {
    // The photo goes up as raw bytes rather than a base64 data URI: the worker
    // does the base64 encoding OpenAI needs, which keeps a third of the weight
    // off the mobile upload.
    final res = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': mime,
        if (_appToken.isNotEmpty) 'X-App-Token': _appToken,
      },
      body: bytes,
    );

    if (res.statusCode != 200) {
      throw CoverScanException(
          'Cover scan request failed (${res.statusCode}): ${res.body}');
    }

    return _parse(res.body);
  }

  /// The worker already de-duplicates, sorts and truncates, but the same
  /// normalisation runs here so a malformed response can't reach the UI.
  List<TitleCandidate> _parse(String responseBody) {
    final body = jsonDecode(responseBody) as Map<String, dynamic>;
    final titles = body['titles'] as List<dynamic>? ?? [];

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
