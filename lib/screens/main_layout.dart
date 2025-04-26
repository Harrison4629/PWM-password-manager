import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nav_providers.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'list_screen.dart';
import 'settings_screen.dart';

// Change back to ConsumerWidget
class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  static const List<Widget> _widgetOptions = <Widget>[ HomeScreen(), ListScreen(), SettingsScreen(), ];
  static const List<String> _widgetTitles = [ 'PWM 主页', '密码列表', '设置', ];
  // 图标对 [未选中图标, 选中图标]
  static const List<List<IconData>> _navIconPairs = [
    [Icons.home_outlined, Icons.home],
    [Icons.list_alt_outlined, Icons.list_alt],
    [Icons.settings_outlined, Icons.settings],
  ];
  static const List<String> _navLabels = [ '主页', '列表', '设置', ];

  // Remove createState and the State class (_MainLayoutState)
  // Move build method back here
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);
    final theme = Theme.of(context);
    final Duration animationDuration = const Duration(milliseconds: 300); // 统一动画时长

    // Remove the buildAppBarBottom function and the AppBar bottom property
    return Scaffold(
      appBar: AppBar(
        title: Text(_widgetTitles[selectedIndex]), // Use static member directly
        centerTitle: false,
        // No bottom property here anymore
      ),
      body: IndexedStack( index: selectedIndex, children: _widgetOptions, ), // Use static member directly
      bottomNavigationBar: Container(
        height: 75, // 保持或调整高度
        decoration: BoxDecoration(
          color: kAppBarFooterColor,
          boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2), ) ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navIconPairs.length, (index) { // Use static member directly
              final isSelected = index == selectedIndex;
              final Color activeColor = kPrimaryColor;
              final Color inactiveColor = Colors.grey[600]!;
              const double baseIconSize = 24;
              // 选中和未选中时的大小可以相同，或者微调
              final double currentIconSize = isSelected ? baseIconSize + 1 : baseIconSize; // 选中时稍微大一点点

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref.read(bottomNavIndexProvider.notifier).state = index;
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 容器仍然负责背景 "药丸" 效果和可能的轻微上移动画
                      AnimatedContainer(
                        duration: animationDuration,
                        curve: Curves.easeOut,
                        padding: EdgeInsets.symmetric(
                          // 根据需要调整内边距，确保图标有空间
                          vertical: isSelected ? 5.0 : 6.0,
                          horizontal: isSelected ? 18.0 : 10.0
                        ),
                        // 移除 transform 或保持原来的轻微上移
                        // transform: Matrix4.translationValues(0, isSelected ? -1.0 : 0, 0),
                        // transformAlignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(50), // 保持胶囊形状
                        ),
                        // --- 使用 Stack 叠加图标 ---
                        child: Stack(
                          alignment: Alignment.center, // 确保图标居中对齐
                          children: [
                            // 1. 底层：Outlined Icon (颜色和大小根据选中状态变化)
                            Icon(
                              _navIconPairs[index][0], // Use static member directly
                              color: isSelected ? activeColor : inactiveColor, // 选中时轮廓也变色
                              size: currentIconSize, // 应用动态大小
                            ),
                            // 2. 顶层：Filled Icon (通过透明度动画显示/隐藏)
                            AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.0, // 选中时完全不透明，否则完全透明
                              duration: animationDuration,   // 与容器动画时长一致
                              curve: Curves.easeIn,          // 淡入效果可以使用 easeIn
                              child: Icon(
                                _navIconPairs[index][1], // Use static member directly
                                color: activeColor,        // 填充图标始终用 activeColor
                                size: currentIconSize,    // 应用动态大小
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 文本标签动画
                      AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: animationDuration,
                        child: SizedBox(
                          height: isSelected ? 16 : 0,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              _navLabels[index], // Use static member directly
                              style: const TextStyle(
                                fontSize: 11,
                                color: kPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.clip,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
