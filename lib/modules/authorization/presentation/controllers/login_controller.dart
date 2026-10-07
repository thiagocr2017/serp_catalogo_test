import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/auth_api.dart';

final loginControllerProvider =
    NotifierProvider<LoginController, AsyncValue<void>>(
      LoginController.new,
    );

class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> login(String email, String password) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithPassword(email, password);
    });
  }
}
