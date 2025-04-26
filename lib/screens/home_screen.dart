import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import '../providers/password_providers.dart';
import 'add_edit_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passwordListAsyncValue = ref.watch(passwordListProvider);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary; // 获取主题的主色调

    // 定义波浪颜色 - 基于主题主色调，改变透明度
    final List<Color> waveColors = [
      primaryColor.withOpacity(0.12), // 最底层，最透明
      primaryColor.withOpacity(0.20),
      primaryColor.withOpacity(0.28),
      primaryColor.withOpacity(0.36), // 最顶层，最不透明
    ];

    // 定义波浪动画时长 (毫秒) - 不同的时长产生流动的效果
    // 不同的时长会产生流动的效果
    final List<int> waveDurations = [
      5000,
      7000,
      10000,
      12000,
    ];

    // 定义波浪高度百分比
    // 相对于 Widget 高度的百分比
    final List<double> waveHeightPercentages = [
      0.59, // 对应 waveColors[0]
      0.64, // 对应 waveColors[1]
      0.67, // 对应 waveColors[2]
      0.70, // 对应 waveColors[3] (最顶层波浪的基线位置)
    ];


    return Scaffold(
      // 将波浪放在 Scaffold 的 body 背景上
      body: Stack( // 使用 Stack 进行分层
        children: [
          // 底层：波浪动画
          // 让 WaveWidget 填充整个 Stack
          Positioned.fill(
            child: WaveWidget(
              // 波浪动画配置
              config: CustomConfig(
                colors: waveColors, // 使用基于主题的颜色
                durations: waveDurations, // 使用预设的时长
                heightPercentages: waveHeightPercentages,
              ),
              // 波浪振幅，控制波浪的起伏高度
              waveAmplitude: 20.0,
              // 波浪层下方的背景色，应与 Scaffold 背景色一致
              backgroundColor: theme.scaffoldBackgroundColor,
              // 波浪的大小，使其填充整个父级 Stack
              size: const Size(double.infinity, double.infinity),
              // 可选：设置波浪相位偏移，增加视觉随机性
              wavePhase: 10.0,
              // isLoop: true, // 循环播放默认即为 true
            ),
          ),

          // 上层：屏幕主要内容
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0), // 内容区域的内边距
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 80,
                    color: theme.colorScheme.primary, // 使用主题色
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '欢迎使用 PWM',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onBackground, // 确保文字颜色在背景上可见
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                   Text(
                    '您的安全密码管家',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor, // 使用次要颜色
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  passwordListAsyncValue.when(
                     data: (list) => Text(
                       '已安全存储 ${list.length} 条密码记录',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onBackground),
                        textAlign: TextAlign.center,
                      ),
                     loading: () => const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(width: 8), Text('加载中...')]), // 加载指示器
                     error: (e, s) => Tooltip(message: '加载密码列表失败: $e', child: const Icon(Icons.error_outline, color: Colors.red)), // 错误提示
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('添加新密码记录'),
                    // style 属性为空，默认使用主题定义的 ElevatedButtonTheme
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddEditScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
