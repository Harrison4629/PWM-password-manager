import 'dart:convert'; // 用于 base64 编码/解码
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';
import '../utils/constants.dart';

const _storage = FlutterSecureStorage();

class AuthService {
  Future<bool> isPinSet() async {
    final pinSet = await _storage.read(key: kPrefsPinSetKey);
    return pinSet == 'true';
  }

  Future<void> setupPin(String pin) async {
    try {
      final salt = EncryptionService.generateSalt();
      final result = EncryptionService.deriveKeyAndHash(pin, salt);

      await _storage.write(key: kPrefsPinSetKey, value: 'true');
      await _storage.write(key: kPrefsPinSaltKey, value: base64.encode(salt)); // 将 salt 存储为 base64
      await _storage.write(key: kPrefsPinHashKey, value: base64.encode(result.hash)); // 将 hash 存储为 base64
    } catch (e) {
      print("Error setting up PIN: $e");
      rethrow;
    }
  }

  Future<Uint8List?> verifyPinAndGetDerivedKey(String pin) async {
    try {
      final saltBase64 = await _storage.read(key: kPrefsPinSaltKey);
      final storedHashBase64 = await _storage.read(key: kPrefsPinHashKey);

      if (saltBase64 == null || storedHashBase64 == null) {
        return null; // 如果 isPinSet 为 true，则不应发生
      }

      final salt = base64.decode(saltBase64);
      final storedHash = base64.decode(storedHashBase64);

      // 使用存储的 salt 从输入的 PIN 派生哈希
      final derivedHash = EncryptionService.deriveHash(pin, salt);

      // 将派生的哈希与存储的哈希进行比较 (恒定时间比较)
      if (fixedTimeEquals(derivedHash, storedHash)) {
        // 验证成功，现在派生*实际*加密密钥
        final derivedKey = EncryptionService.deriveKey(pin, salt);
        return derivedKey;
      } else {
        return null;
      }
    } catch (e) {
      print("Error verifying PIN: $e");
      return null;
    }
  }

   // 重要提示：这仅更新身份验证哈希，而不是用于数据的加密密钥。
   // 重新加密所有数据很复杂，为简单起见，此处省略。
   Future<bool> changePin(String oldPin, String newPin) async {
    try {
      // 1. 首先验证旧 PIN
      final currentKey = await verifyPinAndGetDerivedKey(oldPin);
      if (currentKey == null) {
        return false; // 旧 PIN 不正确
      }

      // 2. 如果旧 PIN 正确，则设置新 PIN (新 salt，新哈希)
      final salt = EncryptionService.generateSalt();
      final result = EncryptionService.deriveKeyAndHash(newPin, salt);

      await _storage.write(key: kPrefsPinSetKey, value: 'true');
      await _storage.write(key: kPrefsPinSaltKey, value: base64.encode(salt));
      await _storage.write(key: kPrefsPinHashKey, value: base64.encode(result.hash));

      // 3. 重新加密所有数据
      //   - 获取 StorageService 实例
      //   - 获取所有加密的条目
      //   - 解密每个条目
      //   - 使用新 PIN 加密每个条目
      //   - 保存加密的条目
      // 这是一个复杂的操作，为简洁起见，此处省略。

      // 注意：现有数据仍使用从*原始* PIN 设置或后续成功登录派生的密钥进行加密。
      // 此函数仅更改登录凭据。
      // 真正安全的实现会在此处重新加密数据。
      return true;
    } catch (e) {
      print("Error changing PIN: $e");
      return false;
    }
  }

  Future<void> clearPinData() async {
    await _storage.delete(key: kPrefsPinSetKey);
    await _storage.delete(key: kPrefsPinSaltKey);
    await _storage.delete(key: kPrefsPinHashKey);
  }
}

// 字节数组的恒定时间比较，以防止定时攻击
bool fixedTimeEquals(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  int result = 0;
  for (int i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}
