import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/services/auth_context.dart';
import 'package:zenpose/services/auth_service.dart';

void main() {
  test(
    'restoreSession reports unconfigured when Supabase is disabled',
    () async {
      final service = AuthService.instance;
      service.configure(enabled: false);

      final state = await service.restoreSession();

      expect(state.status, AuthStatus.unconfigured);
      expect(AuthContext.activeUserId, AuthContext.localUserId);
    },
  );
}
