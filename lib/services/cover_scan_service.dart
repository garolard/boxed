import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Extracts candidate title strings from a photo of a game cover
/// using on-device ML Kit text recognition.
class CoverScanService {
  final ImagePicker _picker = ImagePicker();

  Future<List<String>> scan({bool fromCamera = true}) async {
    final photo = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
    );
    if (photo == null) return [];

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(photo.path));
      return _candidates(result);
    } finally {
      await recognizer.close();
    }
  }

  /// Cover titles are usually the biggest text blocks; ML Kit gives no font
  /// size directly, so rank lines by bounding-box height and filter noise
  /// (ratings logos, platform banners, publisher names are usually smaller).
  List<String> _candidates(RecognizedText text) {
    final lines = <(String, double)>[];
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final value = line.text.trim();
        if (value.length < 3) continue;
        if (!RegExp(r'[a-zA-Z]{3}').hasMatch(value)) continue;
        lines.add((value, line.boundingBox.height.toDouble()));
      }
    }
    lines.sort((a, b) => b.$2.compareTo(a.$2));

    final seen = <String>{};
    final candidates = <String>[];
    for (final (value, _) in lines) {
      final normalized = value.toLowerCase();
      if (seen.add(normalized)) candidates.add(value);
      if (candidates.length >= 6) break;
    }
    // Also offer the two biggest lines joined, for multi-line titles
    // like "THE LEGEND OF" / "ZELDA".
    if (candidates.length >= 2) {
      candidates.insert(2, '${candidates[0]} ${candidates[1]}');
    }
    return candidates;
  }
}
