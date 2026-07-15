import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

/// Reads QR codes from a photo (camera or gallery) using on-device
/// ML Kit barcode scanning. Photo capture instead of a live preview:
/// live-camera scanner plugins currently fail to build under this
/// project's AGP 9 toolchain.
class QrScanService {
  final ImagePicker _picker = ImagePicker();

  /// Returns the raw string values of all QR codes found in the picked
  /// image, or null when the user cancelled the picker.
  Future<List<String>?> scan({bool fromCamera = true}) async {
    final photo = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
    );
    if (photo == null) return null;

    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final barcodes =
          await scanner.processImage(InputImage.fromFilePath(photo.path));
      return [
        for (final b in barcodes)
          if (b.rawValue != null) b.rawValue!,
      ];
    } finally {
      await scanner.close();
    }
  }
}
