import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

/// One game reference inside a shared-collection QR payload.
class QrEntry {
  final int gameId;
  final int? platformId;
  const QrEntry(this.gameId, this.platformId);
}

class QrPayload {
  final String name;
  final List<QrEntry> entries;
  const QrPayload({required this.name, required this.entries});
}

/// Compact binary codec for sharing a collection through a single QR code.
///
/// A full export JSON is ~1KB per game and a QR holds ~3KB, so the QR
/// carries only (gameId, platformId) pairs plus a label; the receiver
/// re-fetches metadata from IGDB. Layout: version byte, varint-length
/// UTF-8 name, varint count, then per entry a varint gameId delta
/// (ids sorted ascending) and a varint platformId+1 (0 = none).
/// The buffer is gzipped when that helps, then base64url-encoded behind
/// a `vgc1:` (raw) or `vgcz:` (gzip) prefix.
class QrPayloadCodec {
  static const maxGames = 150;
  static const maxNameChars = 40;
  static const _rawPrefix = 'vgc1:';
  static const _gzPrefix = 'vgcz:';

  static String encode(QrPayload payload) {
    if (payload.entries.length > maxGames) {
      throw ArgumentError('Payload exceeds $maxGames games');
    }
    final b = BytesBuilder();
    b.addByte(1);
    var name = payload.name.trim();
    if (name.length > maxNameChars) name = name.substring(0, maxNameChars);
    final nameBytes = utf8.encode(name);
    _writeVarint(b, nameBytes.length);
    b.add(nameBytes);

    final sorted = [...payload.entries]
      ..sort((a, c) => a.gameId.compareTo(c.gameId));
    _writeVarint(b, sorted.length);
    var prev = 0;
    for (final e in sorted) {
      _writeVarint(b, e.gameId - prev);
      prev = e.gameId;
      _writeVarint(b, (e.platformId ?? -1) + 1);
    }

    final raw = b.toBytes();
    final zipped = gzip.encode(raw);
    return zipped.length < raw.length
        ? _gzPrefix + base64UrlEncode(zipped)
        : _rawPrefix + base64UrlEncode(raw);
  }

  /// Returns null when [text] is not a Boxed payload at all;
  /// throws [FormatException] when it is one but corrupt.
  static QrPayload? decode(String text) {
    final Uint8List bytes;
    try {
      if (text.startsWith(_gzPrefix)) {
        bytes = Uint8List.fromList(
            gzip.decode(base64Url.decode(_padded(text.substring(5)))));
      } else if (text.startsWith(_rawPrefix)) {
        bytes = base64Url.decode(_padded(text.substring(5)));
      } else {
        return null;
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Corrupt payload: $e');
    }

    final r = _Reader(bytes);
    if (r.byte() != 1) {
      throw const FormatException('Unsupported payload version');
    }
    final nameLen = r.varint();
    final name = utf8.decode(r.bytes(nameLen));
    final count = r.varint();
    if (count > maxGames) {
      throw const FormatException('Payload game count out of range');
    }
    final entries = <QrEntry>[];
    var prev = 0;
    for (var i = 0; i < count; i++) {
      prev += r.varint();
      final p = r.varint();
      entries.add(QrEntry(prev, p == 0 ? null : p - 1));
    }
    return QrPayload(name: name, entries: entries);
  }

  static String _padded(String s) =>
      s + '=' * ((4 - s.length % 4) % 4);

  static void _writeVarint(BytesBuilder b, int v) {
    if (v < 0) throw ArgumentError('varint must be non-negative: $v');
    while (v >= 0x80) {
      b.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    b.addByte(v);
  }
}

class _Reader {
  final Uint8List _data;
  int _off = 0;
  _Reader(this._data);

  int byte() {
    if (_off >= _data.length) {
      throw const FormatException('Truncated payload');
    }
    return _data[_off++];
  }

  int varint() {
    var result = 0, shift = 0;
    while (true) {
      final b = byte();
      result |= (b & 0x7f) << shift;
      if (b < 0x80) return result;
      shift += 7;
      if (shift > 35) throw const FormatException('Varint too long');
    }
  }

  Uint8List bytes(int n) {
    if (_off + n > _data.length) {
      throw const FormatException('Truncated payload');
    }
    final out = _data.sublist(_off, _off + n);
    _off += n;
    return out;
  }
}
