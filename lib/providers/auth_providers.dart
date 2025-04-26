import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

// AuthService 自身的 Provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// 用于检查 PIN 是否已初始设置的 Provider
final isPinSetProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return authService.isPinSet();
});

// StateNotifierProvider 用于管理认证状态 (已登录或未登录)
// 并在登录后安全地在内存中持有派生密钥。
enum AuthState { unknown, authenticated, unauthenticated, checking }

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  Uint8List? _derivedKey; // 仅在认证时存储密钥

  AuthStateNotifier(this._authService) : super(AuthState.unknown) {
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    state = AuthState.checking;
    final pinIsSet = await _authService.isPinSet();
    state = pinIsSet ? AuthState.unauthenticated : AuthState.unknown; // Unknown 表示需要设置
  }

  Future<bool> setupPin(String pin) async {
    try {
      await _authService.setupPin(pin);
      // 设置后，视为已登出，需要首次登录
      _derivedKey = null;
      state = AuthState.unauthenticated;
      return true;
    } catch (e) {
      // 处理错误
      print("Error setting up PIN: $e");
      return false;
    }
  }

  Future<bool> login(String pin) async {
    try {
      state = AuthState.checking;
      _derivedKey = null; // 清除之前的密钥 (如果有)
      final key = await _authService.verifyPinAndGetDerivedKey(pin);
      if (key != null) {
        _derivedKey = key;
        state = AuthState.authenticated;
        return true;
      } else {
        state = AuthState.unauthenticated;
        return false;
      }
    } catch (e) {
      // 处理错误
      print("Error logging in: $e");
      state = AuthState.unauthenticated;
      return false;
    }
  }

   Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // 尝试使用服务更改 PIN
      final success = await _authService.changePin(oldPin, newPin);
      if (success) {
         // 如果 PIN 更改成功，强制登出以使用新 PIN 重新认证
         logout();
      }
      return success;
    } catch (e) {
      // 处理错误
      print("Error changing PIN: $e");
      return false;
    }
   }

  void logout() {
    _derivedKey = null; // 清除密钥
    // 仅当之前设置了 PIN 时才转换到 unauthenticated
    _authService.isPinSet().then((isSet) {
        if (isSet) {
             state = AuthState.unauthenticated;
        } else {
            // 理论上不应在调用 logout 时发生，但进行防御性处理
             state = AuthState.unknown;
        }
    });

  }

  // Getter，仅在认证时公开密钥
  Uint8List? get derivedKey => (state == AuthState.authenticated) ? _derivedKey : null;
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref.watch(authServiceProvider));
});

// 公开派生密钥的 Provider (如果未认证则返回 null)
// EncryptionService 和 StorageService 将依赖此 Provider。
final derivedKeyProvider = Provider<Uint8List?>((ref) {
  // 监听 AuthStateNotifier 以获取密钥
  final authNotifier = ref.watch(authStateProvider.notifier);
  // 仅在认证时返回密钥
  return authNotifier.derivedKey;
});
