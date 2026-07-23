import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scan_quota_service.dart';
import 'services.dart';

/// Live stream of the current scan quota.
final scanQuotaProvider = StreamProvider<ScanQuota>((ref) {
  return ref.read(scanQuotaServiceProvider).quotaStream();
});
