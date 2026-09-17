import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return FirestoreChatRepository();
});
