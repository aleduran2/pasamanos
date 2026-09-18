import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fcm_token_service.dart';

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FirebaseFcmTokenService();
});
