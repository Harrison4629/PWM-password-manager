import 'package:flutter_riverpod/flutter_riverpod.dart';

// 管理 BottomNavigationBar 当前选中的索引
final bottomNavIndexProvider = StateProvider<int>((ref) => 0); // 默认选中第一个标签页 (主页)
