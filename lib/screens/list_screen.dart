import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/password_providers.dart';
import 'add_edit_screen.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key});

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

// Re-add TextEditingController and dispose
class _ListScreenState extends ConsumerState<ListScreen> {
  final TextEditingController _searchController = TextEditingController();

  // initState 在此场景下无需覆盖，因为没有需要在 state 初始化时执行的特殊逻辑

  @override
  void dispose() {
    _searchController.dispose(); // Add back dispose
    super.dispose();
  }
  // 显示删除确认对话框的函数
  Future<bool?> _showDeleteConfirmation(BuildContext context) {
      return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这条记录吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordsAsyncValue = ref.watch(filteredPasswordListProvider);
    final currentSearchQuery = ref.watch(searchQueryProvider);
    final theme = Theme.of(context);

    // Removed Scaffold and AppBar here, as MainLayout provides them.
    // The content now directly returns the Column.
    return Column(
        children: [
          // Re-add search bar Padding and TextField here
          SizedBox(
            height: 80.0, // Adjust this value to move the search bar vertically
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Add top padding here
              child: TextField(
                controller: _searchController, // Use the controller
                decoration: InputDecoration(
                  hintText: '搜索标题或账号...',
                  hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.6)),
                  prefixIcon: Icon(Icons.search, size: 20, color: theme.hintColor.withOpacity(0.8)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  // Use watched query state for clear button
                  suffixIcon: currentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 20, color: theme.hintColor.withOpacity(0.8)),
                        tooltip: '清除搜索',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                ),
                onChanged: (value) {
                  // Update provider on change
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),
          // 列表区域 (占据剩余空间)
          Expanded(
            child: passwordsAsyncValue.when(
              // 数据加载完成状态
              data: (passwords) {
                // 如果列表为空则显示消息
                if (passwords.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        currentSearchQuery.isNotEmpty
                            ? '没有找到匹配 "$currentSearchQuery" 的记录'
                            : '还没有保存密码记录\n点击右下角 + 添加一个吧',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.disabledColor,
                        ),
                      ),
                    ),
                  );
                }
                // 构建可重新排序的列表
                return ReorderableListView.builder(
                  // 禁用默认拖动手柄 (我们使用前置的)
                  buildDefaultDragHandles: false,
                  // 在列表下方添加内边距以避免 FAB 重叠，并添加一些顶部内边距
                  padding: const EdgeInsets.only(bottom: 80, top: 4),

                  // 自定义拖动反馈装饰器
                  proxyDecorator: (Widget child, int index, Animation<double> animation) {
                    // 定义动画参数
                    const double startElevation = 1.0; // 匹配 Card 的正常阴影
                    const double endElevation = 8.0;   // 拖动时增加阴影
                    const double startScale = 1.0;     // 正常缩放比例
                    const double endScale = 1.03;     // 拖动时略微放大

                    // 根据动画进度计算阴影和缩放
                    // 使用 Curves.easeInOut 或类似曲线以实现更平滑的过渡
                    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                    final double elevation = Tween<double>(begin: startElevation, end: endElevation).evaluate(curvedAnimation);
                    final double scale = Tween<double>(begin: startScale, end: endScale).evaluate(curvedAnimation);

                    // 返回 Material 小部件以根据形状正确渲染阴影
                    return Material(
                      color: Colors.transparent, // 让 Card 的颜色透出来
                      // 阴影使用与 Card 相同的形状
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      shadowColor: Colors.black.withOpacity(0.1), // 拖动时阴影颜色（可选，可微调）
                      elevation: elevation, // 应用动画阴影
                      // 应用动画缩放
                      child: Transform.scale(
                         scale: scale, // 应用动画缩放
                         child: child, // 正在拖动的原始 ListTile (包裹在 Card 中)
                      ),
                    );
                  },

                  itemCount: passwords.length, // 列表项数量
                  itemBuilder: (context, index) {
                    final entry = passwords[index];
                    // 使用 Card 作为项目背景、形状和间距
                    return Card(
                      key: ValueKey(entry.id), // 对重新排序逻辑至关重要
                      elevation: 1.0, // 正常状态阴影
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12), // 间距
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // 圆角
                      clipBehavior: Clip.antiAlias, // 将内容裁剪为圆角
                      child: ListTile(
                      // ListTile 的内边距，调整以适应拖动手柄
                      contentPadding: const EdgeInsets.only(left: 0, right: 12, top: 6, bottom: 6),
                      // 前置部件：拖动手柄图标和监听器
                      leading: ReorderableDragStartListener(
                        index: index, // 关联到当前列表项的索引
                        child: Container( // 容器增大拖动触发区域
                          padding: const EdgeInsets.symmetric(horizontal: 16.0), // 水平内边距
                          child: Icon(Icons.drag_handle, color: theme.disabledColor) // 拖动手柄视觉元素
                        ),
                      ),
                      // 主要显示内容：标题和账号
                        title: Text(
                          entry.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.account,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // 尾部部件：删除按钮
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error.withOpacity(0.8)), // 删除图标，使用错误颜色
                        tooltip: '删除记录', // 提示文本
                        onPressed: () async {
                          // 弹出确认对话框
                          final confirm = await _showDeleteConfirmation(context);
                          // 如果用户确认删除
                          if (confirm == true) {
                            // 调用 Provider 执行删除操作
                            ref.read(passwordListProvider.notifier).deleteEntry(entry.id);
                            // 异步操作后，检查 Widget 是否仍在树中
                            if (context.mounted) {
                               ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar() // 隐藏之前的 SnackBar (如果有)
                                ..showSnackBar(const SnackBar( // 显示删除成功提示
                                      content: Text('记录已删除'),
                                      duration: Duration(seconds: 2),
                                    ));
                              }
                            }
                          },
                        ),
                        // 整个条目的点击操作：编辑
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditScreen(entry: entry),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  // 重新排序完成时的回调
                  onReorder: (oldIndex, newIndex) {
                    // 在回调中使用 ref.read
                    ref.read(passwordListProvider.notifier).reorderEntries(oldIndex, newIndex);
                  },
                );
              },
              // 加载状态
              loading: () => const Center(child: CircularProgressIndicator(key: Key("list_loading"))),
              // 错误状态
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
                       const SizedBox(height: 16),
                       Text(
                         '加载密码列表时出错',
                         style: theme.textTheme.headlineSmall,
                         textAlign: TextAlign.center,
                       ),
                       const SizedBox(height: 8),
                        Text(
                           '$err', // 显示实际的错误消息
                           textAlign: TextAlign.center,
                           style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                       const SizedBox(height: 20),
                       ElevatedButton.icon( // 重试按钮
                         icon: const Icon(Icons.refresh),
                         label: const Text('重试'),
                         onPressed: () {
                           // 使 provider 失效以触发重新加载尝试
                           ref.invalidate(passwordListProvider);
                         },
                       )
                    ],
                  )
                ),
              ),
            ),
          ),
        ],
      );
      // FloatingActionButton is managed by MainLayout or the parent Scaffold now.
      // Removed FAB from here.
  }
}
