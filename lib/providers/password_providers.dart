import 'dart:async'; // 用于异步操作和 StackTrace
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod 核心库
import '../models/password_entry.dart'; // 密码条目模型
import '../services/storage_service.dart'; // 存储服务
import '../services/encryption_service.dart'; // 加密服务
import 'auth_providers.dart'; // 认证相关的 Provider，依赖 derivedKeyProvider

// --- 核心服务 Providers ---

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  final derivedKey = ref.watch(derivedKeyProvider);
  // print("EncryptionServiceProvider rebuilt. Key available: ${EncryptionService(derivedKey).isKeyAvailable}");
  return EncryptionService(derivedKey);
});

final storageServiceProvider = FutureProvider<StorageService>((ref) async {
  // print("[StorageServiceProvider] FutureProvider executing...");
  final service = StorageService(ref);
  await service.init();
  // print("[StorageServiceProvider] Initialization COMPLETE.");
  return service;
});


// --- 密码列表状态管理 ---

final passwordListProvider = StateNotifierProvider<PasswordListNotifier, AsyncValue<List<PasswordEntry>>>((ref) {
  final storageServiceAsyncValue = ref.watch(storageServiceProvider);
  // print("[PasswordListProvider] Rebuilding. Watched storageServiceAsyncValue state is: ${storageServiceAsyncValue.runtimeType}");

  return storageServiceAsyncValue.when(
    data: (storageService) => PasswordListNotifier(storageService)..loadEntriesIfNeeded(),
    loading: () => PasswordListNotifier(null, initialState: const AsyncValue.loading()),
    error: (err, stack) => PasswordListNotifier(null, initialState: AsyncValue.error(err, stack)),
  );
});


// 管理密码列表状态的 StateNotifier 类
class PasswordListNotifier extends StateNotifier<AsyncValue<List<PasswordEntry>>> {
  final StorageService? _storageService;
  bool _initialLoadAttempted = false;
  bool _isLoadingEntries = false;

  /// 构造函数
  PasswordListNotifier(this._storageService, {AsyncValue<List<PasswordEntry>> initialState = const AsyncValue.loading()})
      : super(initialState);

  /// 如果条件满足，则触发条目的初始加载。
  void loadEntriesIfNeeded() {
      if (_storageService != null && !_initialLoadAttempted && state is! AsyncError) {
         _initialLoadAttempted = true;
         loadEntries();
      }
  }

  /// 从 StorageService 加载 (或重新加载) 所有密码条目。
  Future<void> loadEntries() async {
    if (_storageService == null) {
       state = _ensureErrorState("存储服务未初始化");
       return;
    }
    if (_isLoadingEntries) return;
    _isLoadingEntries = true;
    // 显式设置 loading 状态，即使之前是 loading
    state = const AsyncValue.loading();
    try {
      final entries = _storageService!.getEntries();
      state = AsyncValue.data(entries);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    } finally {
      _isLoadingEntries = false;
    }
  }

  /// 添加一个新的密码条目到存储中，并重新加载列表。
  Future<void> addEntry(PasswordEntry entry) async {
     if (_storageService == null) {
         state = _ensureErrorState("无法添加条目：存储服务不可用");
         return;
     }
      try {
        await _storageService!.addEntry(entry);
        await loadEntries();
      } catch (e, stack) {
         state = AsyncValue.error(e, stack);
      }
   }

  /// 更新一个现有的密码条目，并重新加载列表。
  Future<void> updateEntry(PasswordEntry entry) async {
     if (_storageService == null) {
         state = _ensureErrorState("无法更新条目：存储服务不可用");
         return;
     }
      try {
         await _storageService!.updateEntry(entry);
         await loadEntries();
     } catch (e, stack) {
         state = AsyncValue.error(e, stack);
     }
  }

  /// 根据 ID 删除一个密码条目，并重新加载列表。
  Future<void> deleteEntry(String id) async {
     if (_storageService == null) {
        state = _ensureErrorState("无法删除条目：存储服务不可用");
        return;
     }
      try {
         await _storageService!.deleteEntry(id);
         await loadEntries();
      } catch (e, stack) {
         state = AsyncValue.error(e, stack);
      }
  }

  /// 处理密码条目的重新排序操作。
  Future<void> reorderEntries(int oldIndex, int newIndex) async {
      if (state is! AsyncData<List<PasswordEntry>>) {
          print("无法重新排序：当前状态不是 AsyncData");
          return;
      }
      if (_storageService == null) {
           state = _ensureErrorState("无法重新排序条目：存储服务不可用");
           return;
      }

      // --- 保存乐观更新之前的状态 ---
      final previousState = state as AsyncData<List<PasswordEntry>>; // Cast is safe here
      final currentList = List<PasswordEntry>.from(previousState.value);
      // --- 保存结束 ---

      // Perform local reordering
      final list = List<PasswordEntry>.from(currentList);
      final item = list.removeAt(oldIndex);
      if (newIndex > oldIndex) newIndex -= 1;
      list.insert(newIndex, item);

      // Update order property
      final List<PasswordEntry> updatedOrderList = [];
      for (int i = 0; i < list.length; i++) {
          updatedOrderList.add(list[i].copyWith(order: i));
      }

      // Optimistic UI Update
      state = AsyncValue.data(updatedOrderList);

      // Attempt to Persist Change
      try {
          await _storageService!.updateEntryOrder(updatedOrderList);
          // Persistence successful. State already reflects the optimistic update.
      } catch (e, stack) {
          // Persistence failed. Revert state using error with previous data.
          print("[PasswordListNotifier#${hashCode}] reorderEntries: FAILED to persist. Reverting state. Error: $e\n$stack");
          // --- FIX: Use copyWithPrevious on a typed error value ---
          // 1. Create a typed error value first
          final errorValue = AsyncValue<List<PasswordEntry>>.error(
              "无法保存新顺序: $e",
              stack
          );
          // 2. Copy the previous successful state onto the error state
          state = errorValue.copyWithPrevious(previousState);
          // --- End FIX ---
      }
  }

  /// 辅助函数：安全地设置错误状态。
  AsyncValue<List<PasswordEntry>> _ensureErrorState(String message, [Object? error, StackTrace? stackTrace]) {
     if (state is! AsyncError) {
       return AsyncValue.error(error ?? message, stackTrace ?? StackTrace.current);
     }
     return state;
   }
}


// --- 搜索和过滤 ---
final searchQueryProvider = StateProvider<String>((ref) => '');
final filteredPasswordListProvider = Provider<AsyncValue<List<PasswordEntry>>>((ref) {
  final passwordListAsyncValue = ref.watch(passwordListProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  return passwordListAsyncValue.whenData((allPasswords) {
    if (query.isEmpty) return allPasswords;
    return allPasswords.where((entry) {
      return entry.title.toLowerCase().contains(query) ||
             entry.account.toLowerCase().contains(query);
    }).toList();
  });
});