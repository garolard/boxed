import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vgcollection/services/cover_scan_service.dart';

/// Captures the downscaling arguments the service asks [ImagePicker] for and
/// hands back a stub photo, so the upload path can run without a device.
class _RecordingPicker extends ImagePicker {
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  ImageSource? source;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      path: 'cover.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

String _completion(Object titles) => jsonEncode({
      'choices': [
        {
          'message': {
            'content': jsonEncode({'titles': titles}),
          },
        },
      ],
    });

void main() {
  test('downscales the photo before uploading it', () async {
    final picker = _RecordingPicker();
    final service = CoverScanService(
      picker: picker,
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response(_completion([]), 200)),
    );

    await service.scan(fromCamera: true);

    // Both bounds must be set, otherwise the longest edge of a portrait
    // photo goes up at full resolution.
    expect(picker.maxWidth, 768);
    expect(picker.maxHeight, 768);
    expect(picker.imageQuality, 80);
    expect(picker.source, ImageSource.camera);
  });

  test('returns candidates ordered by confidence, de-duplicated', () async {
    late String body;
    final service = CoverScanService(
      picker: _RecordingPicker(),
      apiKey: 'test-key',
      client: MockClient((req) async {
        body = req.body;
        return http.Response(
          _completion([
            {'title': 'Chrono Trigger', 'confidence': 0.4},
            {'title': 'Secret of Mana', 'confidence': 0.9},
            {'title': 'chrono trigger', 'confidence': 0.2},
          ]),
          200,
        );
      }),
    );

    final candidates = await service.scan();

    expect(
      candidates.map((c) => c.title),
      ['Secret of Mana', 'Chrono Trigger'],
    );
    // The photo is inlined as a base64 data URI on the request.
    expect(body, contains('data:image/jpeg;base64,'));
  });

  test('surfaces a non-200 from OpenAI as CoverScanException', () async {
    final service = CoverScanService(
      picker: _RecordingPicker(),
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('nope', 500)),
    );

    expect(service.scan(), throwsA(isA<CoverScanException>()));
  });

  test('returns an empty list when the user cancels the picker', () async {
    final service = CoverScanService(
      picker: _CancellingPicker(),
      apiKey: 'test-key',
      client: MockClient((_) async => fail('must not call OpenAI')),
    );

    expect(await service.scan(), isEmpty);
  });
}

class _CancellingPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      null;
}
