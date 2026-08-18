import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vgcollection/services/cover_scan_service.dart';

const _endpoint = 'https://worker.example/scan';

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

String _titles(Object titles) => jsonEncode({'titles': titles});

void main() {
  test('downscales the photo before uploading it', () async {
    final picker = _RecordingPicker();
    final service = CoverScanService(
      picker: picker,
      endpoint: _endpoint,
      client: MockClient((_) async => http.Response(_titles([]), 200)),
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
    late http.Request request;
    final service = CoverScanService(
      picker: _RecordingPicker(),
      endpoint: _endpoint,
      appToken: 'app-token',
      client: MockClient((req) async {
        request = req;
        return http.Response(
          _titles([
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
    // The photo goes to the worker as raw bytes, not a base64 data URI.
    expect(request.url.toString(), _endpoint);
    expect(request.bodyBytes, [1, 2, 3, 4]);
    expect(request.headers['Content-Type'], 'image/jpeg');
    expect(request.headers['X-App-Token'], 'app-token');
  });

  test('sends no app token when none is configured', () async {
    late http.Request request;
    final service = CoverScanService(
      picker: _RecordingPicker(),
      endpoint: _endpoint,
      client: MockClient((req) async {
        request = req;
        return http.Response(_titles([]), 200);
      }),
    );

    await service.scan();

    expect(request.headers.containsKey('X-App-Token'), isFalse);
  });

  test('surfaces a non-200 from the worker as CoverScanException', () async {
    final service = CoverScanService(
      picker: _RecordingPicker(),
      endpoint: _endpoint,
      client: MockClient((_) async => http.Response('nope', 500)),
    );

    expect(service.scan(), throwsA(isA<CoverScanException>()));
  });

  test('throws when the endpoint is not configured', () async {
    final service = CoverScanService(
      picker: _RecordingPicker(),
      endpoint: '',
      client: MockClient((_) async => fail('must not call the worker')),
    );

    expect(service.scan(), throwsA(isA<CoverScanException>()));
  });

  test('returns an empty list when the user cancels the picker', () async {
    final service = CoverScanService(
      picker: _CancellingPicker(),
      endpoint: _endpoint,
      client: MockClient((_) async => fail('must not call the worker')),
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
