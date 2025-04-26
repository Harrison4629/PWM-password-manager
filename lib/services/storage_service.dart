import 'package:flutter/foundation.dart'; // 用于 kDebugMode
import 'package:hive_flutter/hive_flutter.dart'; // Hive 数据库
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 需要 Ref 来读取 Provider
import '../models/password_entry.dart'; // 密码条目模型
import '../services/encryption_service.dart'; // 需要 EncryptionService 类型和 Provider 键
import '../providers/password_providers.dart'; // 需要 encryptionServiceProvider 键
import '../utils/constants.dart'; // 需要 kHiveBoxName

/// 服务类，负责与本地 Hive 数据库进行交互以存储和检索密码条目。
/// 它使用 Riverpod 的 Ref 在需要时读取当前的 EncryptionService 实例，
/// 确保所有加密/解密操作都使用正确的、与当前认证状态关联的密钥。
class StorageService {
  /// Riverpod 引用，用于读取其他 Provider (如此处的 EncryptionService)。
  final Ref _ref;

  /// Hive Box 实例，用于存储 PasswordEntry 对象。
  /// 这个 Box 是在 `init()` 方法中异步初始化的，因此是可空的。
  Box<PasswordEntry>? _passwordBox;

  /// 构造函数，需要传入 Riverpod 的 Ref 对象。
  StorageService(this._ref);

  /// 辅助方法，用于获取*当前*的 EncryptionService 实例。
  /// 通过 `_ref.read` 读取 Provider 可以确保我们总是获取与最新状态
  /// (例如，用户登录后拥有派生密钥的状态) 相对应的服务实例。
  EncryptionService _getEncryptionService() {
    // 读取 encryptionServiceProvider 以获取当前的加密服务实例
    return _ref.read(encryptionServiceProvider);
  }

  /// 初始化存储服务。
  /// 主要工作是打开 (或获取已打开的) 用于存储密码条目的 Hive Box。
  /// 这个方法必须在调用任何其他需要访问 Box 的方法之前成功完成。
  Future<void> init() async {
    try {
       // 检查名为 kHiveBoxName 的 Box 是否已经打开
       if (!Hive.isBoxOpen(kHiveBoxName)) {
          // 如果未打开，则异步打开它，并指定类型为 PasswordEntry
          _passwordBox = await Hive.openBox<PasswordEntry>(kHiveBoxName);
       } else {
           // 如果已打开，则直接获取该 Box 的实例
           _passwordBox = Hive.box<PasswordEntry>(kHiveBoxName);
       }
    } catch (e, stack) {
       // 如果在打开 Box 时发生错误
       _passwordBox = null; // 将 Box 实例设为 null
       if (kDebugMode) { print("打开 Hive Box '$kHiveBoxName' 失败: $e"); }
       // 重新抛出异常，以便依赖此服务的 FutureProvider 可以进入错误状态
       rethrow;
    }
  }

  /// 检索所有存储的密码条目。
  /// 它会获取所有加密的条目，使用当前的 EncryptionService 进行解密，
  /// 并按 `order` 字段对成功解密的条目进行排序后返回。
  /// 如果某个条目解密失败 (例如，密钥不匹配或数据损坏)，它将被跳过。
  List<PasswordEntry> getEntries() {
    // 确保 Box 已成功初始化并且是打开状态
    if (_passwordBox == null || !_passwordBox!.isOpen) {
        throw StateError("存储服务未正确初始化或 Hive Box 已关闭。");
    }

    // 从 Box 中获取所有值 (PasswordEntry 对象) 并转换为列表
    final encryptedEntries = _passwordBox!.values.toList();

    // 获取当前的加密服务实例，用于解密
    final encryptionService = _getEncryptionService();

    final decryptedEntries = <PasswordEntry>[]; // 用于存储成功解密的条目
    int decryptFailCount = 0; // 记录解密失败的条目数量

    // 遍历所有从 Box 中取出的加密条目
    for (int i = 0; i < encryptedEntries.length; i++) {
      final entry = encryptedEntries[i]; // 当前加密条目
      // 尝试解密 title, account, password 字段
      final decryptedTitle = encryptionService.decrypt(entry.title);
      final decryptedAccount = encryptionService.decrypt(entry.account);
      final decryptedPassword = encryptionService.decrypt(entry.password);

      // 检查所有关键字段是否都成功解密 (即不为 null)
      if (decryptedTitle != null && decryptedAccount != null && decryptedPassword != null) {
         // 如果都成功，则创建一个新的 PasswordEntry (包含解密后的数据) 并添加到结果列表
         decryptedEntries.add(PasswordEntry(
           id: entry.id, // 保留原始 ID
           title: decryptedTitle,
           account: decryptedAccount,
           password: decryptedPassword,
           order: entry.order, // 保留原始 order
         ));
      } else {
         // 如果有任何字段解密失败
         decryptFailCount++;
         // 可选：在调试模式下打印失败条目的 ID，帮助诊断问题
         if (kDebugMode) { print('解密失败: ID ${entry.id}'); }
      }
    }

    // 如果有解密失败的情况，可以在调试模式下打印警告
    if (decryptFailCount > 0 && kDebugMode) {
      print('警告: $decryptFailCount 个条目解密失败，可能由于密钥更改或数据损坏。');
    }

    // 对成功解密的条目列表按 `order` 字段进行升序排序
    decryptedEntries.sort((a, b) => a.order.compareTo(b.order));
    // 返回排序后的解密条目列表
    return decryptedEntries;
  }

  /// 添加一个新的密码条目到存储中。
  /// 在存储之前，会使用当前的 EncryptionService 加密条目的敏感字段。
  Future<void> addEntry(PasswordEntry entry) async {
     // 确保 Box 已准备好
     if (_passwordBox == null || !_passwordBox!.isOpen) {
       throw StateError("存储服务未正确初始化。无法添加条目。");
     }

     // 获取当前的加密服务实例
     final encryptionService = _getEncryptionService();

     // 在执行加密操作前，显式检查加密密钥是否*在此刻*可用
     if (!encryptionService.isKeyAvailable) {
         // 如果密钥不可用 (例如，用户未登录或密钥派生失败)，抛出明确的异常
         throw Exception("加密密钥不可用。无法保存条目。请确保您已登录。");
     }

     // 使用获取到的加密服务实例来加密条目的敏感字段
     final encryptedTitle = encryptionService.encrypt(entry.title);
     final encryptedAccount = encryptionService.encrypt(entry.account);
     final encryptedPassword = encryptionService.encrypt(entry.password);

     // 检查加密操作是否成功 (encrypt 方法在失败时可能返回 null)
     if (encryptedTitle == null || encryptedAccount == null || encryptedPassword == null) {
       // 如果任何一个字段加密失败，抛出异常
       throw Exception("准备存储条目时加密失败。");
     }

     // 创建一个新的 PasswordEntry 对象，包含加密后的数据和原始的 id, order
     final encryptedEntry = PasswordEntry(
       id: entry.id,
       title: encryptedTitle,
       account: encryptedAccount,
       password: encryptedPassword,
       order: entry.order,
     );
     // 使用条目的 ID 作为键，将加密后的条目存入 Hive Box
     await _passwordBox!.put(encryptedEntry.id, encryptedEntry);
  }

  /// 更新一个现有的密码条目。
  /// 类似于 `addEntry`，它会先加密传入条目的敏感字段，然后覆盖 Box 中具有相同 ID 的条目。
  Future<void> updateEntry(PasswordEntry entry) async {
      // 确保 Box 已初始化且打开
      if (_passwordBox == null || !_passwordBox!.isOpen) throw StateError("存储服务未初始化。无法更新条目。");
      // 确保要更新的条目确实存在于 Box 中
      if (!_passwordBox!.containsKey(entry.id)) throw Exception("找不到要更新的 ID 为 ${entry.id} 的条目。");

      // 获取当前的加密服务实例
      final encryptionService = _getEncryptionService();
      // 检查加密密钥是否可用
      if (!encryptionService.isKeyAvailable) throw Exception("加密密钥不可用。无法更新条目。");

      // 加密传入条目的敏感字段
      final encryptedTitle = encryptionService.encrypt(entry.title);
      final encryptedAccount = encryptionService.encrypt(entry.account);
      final encryptedPassword = encryptionService.encrypt(entry.password);

      // 检查加密是否成功
      if (encryptedTitle == null || encryptedAccount == null || encryptedPassword == null) {
       throw Exception("准备更新条目时加密失败。");
      }

      // 创建包含更新后加密数据的 PasswordEntry 对象
      final encryptedEntry = PasswordEntry(
        id: entry.id, // 保持 ID 不变
        title: encryptedTitle,
        account: encryptedAccount,
        password: encryptedPassword,
        order: entry.order, // 使用传入条目的 order
      );
      // 使用相同的 ID 将更新后的加密条目存入 Box，这将覆盖旧条目
      await _passwordBox!.put(entry.id, encryptedEntry);
  }

  /// 更新多个密码条目的顺序 (`order` 字段)。
  /// 这个方法经过优化，避免了不必要的字段重加密。它直接修改存储中条目的 `order` 字段。
  Future<void> updateEntryOrder(List<PasswordEntry> reorderedEntries) async {
     // 确保 Box 已准备好
     if (_passwordBox == null || !_passwordBox!.isOpen) throw StateError("存储服务未初始化。无法更新顺序。");

     // 获取当前的加密服务实例 (虽然此优化后的方法不直接用它加密，但保留检查以防万一)
     final encryptionService = _getEncryptionService();
      // 注意：更新顺序理论上不需要加密密钥，因为我们只修改 order 字段。
      // 但保留检查以防未来逻辑变更或依赖。
      if (!encryptionService.isKeyAvailable) throw Exception("加密密钥不可用。无法更新顺序。");

     final Map<String, PasswordEntry> updates = {}; // 用于存储需要更新的条目 (键: ID, 值: 更新后的 PasswordEntry)

     // 遍历传入的、已经按新顺序排列好的列表 (这些条目包含 *解密* 后的数据)
     for (int i = 0; i < reorderedEntries.length; i++) {
       final decryptedEntry = reorderedEntries[i]; // 当前条目 (解密状态)
       // 从 Hive Box 中获取与此条目 ID 对应的原始的、*加密*的条目
       final originalEncryptedEntry = _passwordBox!.get(decryptedEntry.id);

       // 检查原始加密条目是否存在，并且其存储的 order 是否与新顺序索引 i 不同
       if (originalEncryptedEntry != null && originalEncryptedEntry.order != i) {
          // 如果存在且顺序需要更新，则创建一个新的 PasswordEntry 用于更新
          // 这个新的 Entry 复用了原始加密的 title, account, password 字段
          // 并且只将 order 字段更新为新的索引 i
          updates[decryptedEntry.id] = PasswordEntry(
            id: decryptedEntry.id,
            title: originalEncryptedEntry.title,       // 复用已加密的 title
            account: originalEncryptedEntry.account,   // 复用已加密的 account
            password: originalEncryptedEntry.password, // 复用已加密的 password
            order: i,                                  // 更新为新的顺序索引
          );
       } else if (originalEncryptedEntry == null) {
          // 处理条目在 Box 中意外丢失的情况 (例如，在读取和更新之间被删除)
          // 在调试模式下打印警告
          if (kDebugMode) { print('警告: 在 updateEntryOrder 期间未找到 ID 为 ${decryptedEntry.id} 的条目'); }
       }
       // 如果 originalEncryptedEntry.order == i，表示该条目的顺序未改变，无需更新
     }

     // 如果 `updates` Map 中有需要更新的条目
     if (updates.isNotEmpty) {
       // 使用 Hive 的 `putAll` 方法执行批量更新，这通常比单个 `put` 更高效
       await _passwordBox!.putAll(updates);
     }
   }

  /// 根据提供的 ID 从 Hive Box 中删除一个密码条目。
  /// 这个操作不需要加密服务。
  Future<void> deleteEntry(String id) async {
      // 确保 Box 已准备好
      if (_passwordBox == null || !_passwordBox!.isOpen) throw StateError("存储服务未初始化。无法删除条目。");
      // 检查 Box 中是否包含此 ID 的条目
      if (!_passwordBox!.containsKey(id)) {
         // 如果密钥不存在，则无需执行任何操作，直接返回
         if (kDebugMode) { print("尝试删除不存在的条目: ID $id"); }
         return;
      }
      // 如果密钥存在，则执行删除操作
      await _passwordBox!.delete(id);
  }

  /// 关闭 Hive Box (如果它当前是打开的)。
  /// 在应用关闭或不再需要访问存储时调用此方法，以释放资源。
  Future<void> close() async {
    // 检查 _passwordBox 是否非空且其对应的 Box 是否已打开
    if (_passwordBox != null && _passwordBox!.isOpen) {
       if (kDebugMode) { print("正在关闭 Hive Box '$kHiveBoxName'..."); }
       await _passwordBox!.close(); // 关闭 Box
       _passwordBox = null; // 将实例变量设为 null，表示 Box 已关闭
    }
  }
}
