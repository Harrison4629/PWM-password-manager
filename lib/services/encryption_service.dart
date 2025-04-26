import 'dart:convert'; // 用于 utf8 编码和 base64 编解码
import 'dart:math'; // 需要 Random.secure() 来安全生成种子
import 'package:flutter/foundation.dart'; // 用于 kDebugMode

import 'package:encrypt/encrypt.dart' as enc; // 加密库 (AES-GCM)
import 'package:pointycastle/export.dart'; // PointyCastle 库，用于 PBKDF2 和其他底层加密原语
import '../utils/constants.dart'; // 应用常量 (迭代次数、密钥长度等)

/// 服务类，负责处理应用中的所有加密相关操作：
/// - 使用 PBKDF2 从用户 PIN 和 salt 安全地派生加密密钥和验证哈希。
/// - 使用 AES-GCM 模式对敏感数据 (如密码条目字段) 进行认证加密和解密。
/// - 生成加密安全的随机 salt。
class EncryptionService {
  /// 从用户 PIN 派生出的加密密钥，包装在 KeyParameter 中以供 PointyCastle 使用。
  /// 此字段保持私有，强制通过 `isKeyAvailable` getter 或内部方法访问，增强封装性。
  final KeyParameter? _keyParam;

  /// 构造函数。
  /// 接收一个可能为空的派生密钥 (Uint8List)。如果密钥非空，则将其包装在 KeyParameter 中；
  /// 否则，_keyParam 保持为 null，表示密钥不可用 (例如，用户未登录)。
  EncryptionService(Uint8List? derivedKey)
      : _keyParam = derivedKey != null ? KeyParameter(derivedKey) : null;

  /// 公共 Getter，用于检查加密密钥是否可用。
  /// 如果 _keyParam 不为 null (即构造函数收到了有效的派生密钥)，则返回 true，表示用户已认证且密钥可用。
  /// 否则返回 false。这允许其他服务或 Provider 在执行加密/解密操作前安全地检查密钥状态，
  /// 而无需直接暴露密钥材料。
  bool get isKeyAvailable => _keyParam != null;

  // --- 密钥派生相关静态方法 (主要由 AuthService 调用) ---

  /// 生成一个加密安全的随机 salt (盐)。
  /// Salt 用于 PBKDF2 密钥派生，确保即使密码相同，派生出的密钥也不同。
  /// [length] 参数指定生成的 salt 的字节长度，默认为 `kPbkdf2SaltSize`。
  ///
  /// 实现细节：
  /// 1. 使用 Dart 内置的 `Random.secure()` 获取一个加密安全的随机数生成器。
  /// 2. 生成一个 32 字节 (256 位) 的随机种子，因为 PointyCastle 的 Fortuna PRNG 需要这个长度的种子。
  /// 3. 创建 PointyCastle 的 FortunaRandom 实例 (一个基于 Fortuna 算法的伪随机数生成器)。
  /// 4. 使用第 2 步生成的安全种子来初始化 (seed) FortunaRandom。种子需要包装在 KeyParameter 中。
  /// 5. 使用已播种的 FortunaRandom 生成所需长度 (`length`) 的随机字节序列作为 salt。
  static Uint8List generateSalt([int length = kPbkdf2SaltSize]) {
    try {
      // 1. 获取 Dart 的安全随机数生成器
      final secureRandomDart = Random.secure();
      // 2. 为 Fortuna PRNG 生成一个 256 位的安全种子
      final seedBytes = Uint8List(32);
      for (int i = 0; i < seedBytes.length; i++) {
        // nextInt(256) 生成 0 到 255 之间的随机整数
        seedBytes[i] = secureRandomDart.nextInt(256);
      }
      // 3. 创建 Fortuna PRNG 实例
      final fortunaRandom = FortunaRandom();
      // 4. 使用安全种子初始化 Fortuna PRNG
      fortunaRandom.seed(KeyParameter(seedBytes));
      // 5. 生成所需长度的 salt 字节
      return fortunaRandom.nextBytes(length);
    } catch (e, stack) {
      // 如果在 salt 生成过程中发生严重错误，记录并重新抛出
      if (kDebugMode) { print("Salt 生成失败: $e\n$stack"); }
      rethrow; // 重新抛出，让调用者知道发生了严重问题
    }
  }

  /// 使用 PBKDF2 算法 (配合 HMAC-SHA256) 从给定的密码 (用户 PIN) 和 salt，
  /// 同时派生出用于加密的密钥 (key) 和用于验证密码的哈希 (hash)。
  /// 这种一次性派生两个值的方法可以确保密钥和哈希是基于完全相同的输入和参数生成的。
  ///
  /// [password]: 用户输入的密码 (PIN)。
  /// [salt]: 与此密码关联的唯一 salt。
  /// 返回一个 `Pbkdf2Result` 对象，包含派生出的密钥和哈希。
  static Pbkdf2Result deriveKeyAndHash(String password, Uint8List salt) {
    // 创建 PBKDF2 实例，使用 HMAC-SHA256 作为伪随机函数 (PRF)，块大小为 64 字节
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    // 初始化 PBKDF2 参数：salt, 迭代次数 (kPbkdf2Iterations), 以及期望的总输出长度
    // 总长度是加密密钥长度 (kPbkdf2KeyLength) + 验证哈希长度 (kPbkdf2HashLength)
    pbkdf2.init(Pbkdf2Parameters(salt, kPbkdf2Iterations, kPbkdf2KeyLength + kPbkdf2HashLength));
    // 将密码字符串转换为 UTF-8 字节列表
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    // 执行 PBKDF2 处理，生成组合的字节序列
    final combinedBytes = pbkdf2.process(passwordBytes);
    // 从组合字节中提取前 kPbkdf2KeyLength 字节作为加密密钥
    final key = combinedBytes.sublist(0, kPbkdf2KeyLength);
    // 从组合字节中提取剩余的 kPbkdf2HashLength 字节作为验证哈希
    final hash = combinedBytes.sublist(kPbkdf2KeyLength);
    // 返回包含密钥和哈希的 Pbkdf2Result 对象
    return Pbkdf2Result(key: key, hash: hash);
  }

   /// 仅使用 PBKDF2 从密码 (PIN) 和 salt 派生加密密钥。
   /// 这个方法在用户成功通过身份验证后，需要获取加密密钥以解密数据时使用。
   /// 它只派生密钥部分，不派生哈希。
   ///
   /// [password]: 用户输入的密码 (PIN)。
   /// [salt]: 存储的与用户关联的 salt。
   /// 返回派生出的加密密钥 (Uint8List)。
   static Uint8List deriveKey(String password, Uint8List salt) {
    // 创建 PBKDF2 实例，配置与 deriveKeyAndHash 相同 (HMAC-SHA256)
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    // 初始化 PBKDF2 参数，但这次期望的输出长度仅为加密密钥长度 (kPbkdf2KeyLength)
    pbkdf2.init(Pbkdf2Parameters(salt, kPbkdf2Iterations, kPbkdf2KeyLength));
    // 执行 PBKDF2 处理并直接返回结果 (即加密密钥)
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// 仅使用 PBKDF2 从密码 (PIN) 和 salt 派生验证哈希。
  /// 这个方法在用户尝试登录进行身份验证时使用。
  /// 为了确保验证的正确性，派生哈希的方式必须与 `deriveKeyAndHash` 中派生哈希的方式完全一致。
  /// 因此，它仍然需要派生组合的字节，然后只提取哈希部分。
  ///
  /// [password]: 用户输入的密码 (PIN)。
  /// [salt]: 存储的与用户关联的 salt。
  /// 返回派生出的验证哈希 (Uint8List)。
  static Uint8List deriveHash(String password, Uint8List salt) {
     // 创建 PBKDF2 实例，配置与 deriveKeyAndHash 完全相同
     final pbkdf2Combined = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
     // 初始化 PBKDF2 参数，期望输出总长度 (密钥 + 哈希)
     pbkdf2Combined.init(Pbkdf2Parameters(salt, kPbkdf2Iterations, kPbkdf2KeyLength + kPbkdf2HashLength));
     // 执行 PBKDF2 处理，生成组合字节
     final derivedCombined = pbkdf2Combined.process(Uint8List.fromList(utf8.encode(password)));
     // 从组合字节中提取并返回哈希部分 (从 kPbkdf2KeyLength 索引开始的部分)
     return derivedCombined.sublist(kPbkdf2KeyLength);
  }


  // --- 数据加密/解密操作 ---

  /// 使用 AES-GCM 模式加密给定的纯文本字符串。
  /// AES-GCM 提供认证加密，即同时保证数据的保密性和完整性/真实性。
  ///
  /// [plainText]: 需要加密的原始字符串。
  /// 返回一个 Base64 编码的字符串，其结构为：`[12字节 IV | 加密后的密文 (包含认证标签)]`。
  /// 将 IV (初始化向量/Nonce) 与密文一起存储是 GCM 模式的标准做法。
  /// 如果加密失败 (例如，加密密钥不可用)，则返回 `null`。
  String? encrypt(String plainText) {
    // 使用公共 getter 检查密钥是否已准备好
    if (!isKeyAvailable) {
      if (kDebugMode) { print("加密失败：密钥不可用。"); }
      return null; // 密钥不可用，无法加密
    }
    // 处理空字符串输入：直接返回空字符串。
    // 注意：这表示空字符串加密后还是空字符串，解密空字符串也得到空字符串。
    // 如果需要区分空字符串和加密失败，可以考虑不同的处理方式。
    if (plainText.isEmpty) {
      return '';
    }

    try {
      // 因为 isKeyAvailable 检查通过，_keyParam 在这里保证非空，使用 '!' 安全
      final key = enc.Key(_keyParam!.key); // 从 KeyParameter 获取原始密钥字节
      // 创建 AES 加密器实例，指定使用 GCM 模式
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      // 为本次加密生成一个唯一的、随机的 12 字节 IV (Nonce)
      // 对于 GCM 模式，每次加密使用不同的 IV 至关重要！推荐长度为 12 字节。
      final iv = enc.IV.fromSecureRandom(12);
      // 执行加密操作
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      // 将 IV 的字节和加密后密文的字节合并到一个 Uint8List 中
      // IV 在前，密文在后
      final combinedBytes = Uint8List.fromList(iv.bytes + encrypted.bytes);
      // 将合并后的字节序列编码为 Base64 字符串以便存储或传输
      return base64.encode(combinedBytes);
    } catch (e, stacktrace) {
      // 如果在加密过程中发生任何异常
      if (kDebugMode) { print("加密时发生错误: $e\n$stacktrace"); }
      return null; // 返回 null 表示加密失败
    }
  }

  /// 使用 AES-GCM 模式解密给定的 Base64 编码的字符串。
  /// 这个字符串应该包含前置的 IV 和后续的密文 (包括认证标签)。
  /// 该方法会同时验证数据的真实性 (检查认证标签)。
  ///
  /// [encryptedBase64]: 包含 `[IV | 密文]` 结构的 Base64 编码字符串。
  /// 如果解密和验证成功，返回原始的纯文本字符串。
  /// 如果解密或验证失败 (例如，密钥错误、数据被篡改、格式错误)，或者密钥不可用，则返回 `null`。
  String? decrypt(String encryptedBase64) {
     // 检查密钥是否可用
     if (!isKeyAvailable) {
      if (kDebugMode) { print("解密失败：密钥不可用。"); }
      return null;
     }
     // 处理空字符串输入：解密空字符串得到空字符串
     if (encryptedBase64.isEmpty) {
      return '';
     }

     try {
       // 密钥可用，'!' 安全
       final key = enc.Key(_keyParam!.key);
       // 创建 AES 解密器实例，使用 GCM 模式
       final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
       // 解码 Base64 字符串得到组合的字节序列
       final combinedBytes = base64.decode(encryptedBase64);

       // 验证组合字节的长度是否至少大于 IV 的长度 (12 字节)
       // 如果长度不足，则无法提取 IV 和密文，数据格式错误
       if (combinedBytes.length <= 12) {
         if (kDebugMode) { print("解密失败：数据长度不足 (<= 12 字节)。"); }
         return null;
       }
       // 从组合字节中提取前 12 字节作为 IV
       final ivBytes = combinedBytes.sublist(0, 12);
       // 提取剩余部分作为加密后的密文 (包含认证标签)
       final encryptedBytes = combinedBytes.sublist(12);

       // 创建 IV 对象和 Encrypted 对象
       final iv = enc.IV(ivBytes);
       final encryptedData = enc.Encrypted(encryptedBytes);

       // 执行解密操作。`decrypt` 方法内部会使用 IV，并自动验证认证标签。
       // 如果标签无效 (数据被篡改或密钥错误)，`decrypt` 方法会抛出异常。
       final decrypted = encrypter.decrypt(encryptedData, iv: iv);
       // 解密和验证成功，返回原始纯文本
       return decrypted;
     } catch (e, stacktrace) {
       // 捕获所有可能的解密/验证错误 (如 MacMismatchException, ArgumentError 等)
       // 在调试模式下打印错误信息
       if (kDebugMode) { print("解密时发生错误 (可能是密钥错误或数据损坏): $e"); }
       // 在任何失败情况下返回 null
       return null;
     }
  }
}

/// 辅助类，用于封装 PBKDF2 派生操作的结果，包含加密密钥和验证哈希。
class Pbkdf2Result {
  /// 派生出的用于数据加密的密钥。
  final Uint8List key;
  /// 派生出的用于密码验证的哈希。
  final Uint8List hash;
  /// 构造函数。
  Pbkdf2Result({required this.key, required this.hash});
}
