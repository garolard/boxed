import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vgcollection/services/qr_payload_codec.dart';

void main() {
  test('round-trips name and entries', () {
    final payload = QrPayload(
      name: "Gabriel's shelf 🎮",
      entries: const [
        QrEntry(1068, 33),
        QrEntry(7346, 130),
        QrEntry(1028, null),
      ],
    );
    final decoded = QrPayloadCodec.decode(QrPayloadCodec.encode(payload))!;
    expect(decoded.name, "Gabriel's shelf 🎮");
    expect(decoded.entries.length, 3);
    final byId = {for (final e in decoded.entries) e.gameId: e.platformId};
    expect(byId[1068], 33);
    expect(byId[7346], 130);
    expect(byId[1028], isNull);
  });

  test('150 realistic entries stay well under QR capacity', () {
    final rng = Random(42);
    final payload = QrPayload(
      name: 'Big shelf',
      entries: [
        for (var i = 0; i < 150; i++)
          QrEntry(rng.nextInt(350000) + 1, rng.nextInt(200) + 1),
      ],
    );
    final encoded = QrPayloadCodec.encode(payload);
    expect(encoded.length, lessThan(1200));
    expect(QrPayloadCodec.decode(encoded)!.entries.length, 150);
  });

  test('truncates names longer than 40 chars', () {
    final payload = QrPayload(name: 'x' * 100, entries: const [QrEntry(1, 1)]);
    final decoded = QrPayloadCodec.decode(QrPayloadCodec.encode(payload))!;
    expect(decoded.name.length, 40);
  });

  test('empty name and empty entries round-trip', () {
    final decoded = QrPayloadCodec.decode(
        QrPayloadCodec.encode(const QrPayload(name: '', entries: [])))!;
    expect(decoded.name, '');
    expect(decoded.entries, isEmpty);
  });

  test('foreign QR content returns null', () {
    expect(QrPayloadCodec.decode('https://example.com/whatever'), isNull);
    expect(QrPayloadCodec.decode('plain text'), isNull);
  });

  test('corrupt payloads throw FormatException', () {
    expect(() => QrPayloadCodec.decode('vgc1:!!!not-base64!!!'),
        throwsFormatException);
    expect(() => QrPayloadCodec.decode('vgc1:AQ'), // version ok, truncated
        throwsFormatException);
    final valid = QrPayloadCodec.encode(
        const QrPayload(name: 'a', entries: [QrEntry(5, 1)]));
    expect(() => QrPayloadCodec.decode(valid.substring(0, valid.length - 3)),
        throwsFormatException);
  });

  test('rejects payloads over the game cap', () {
    expect(
      () => QrPayloadCodec.encode(QrPayload(
        name: 'too big',
        entries: [for (var i = 1; i <= 151; i++) QrEntry(i, null)],
      )),
      throwsArgumentError,
    );
  });
}
