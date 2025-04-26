// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 导入 Pinput 如果你要测试它的存在
// import 'package:pinput/pinput.dart';

// 导入你的应用入口文件
// 确保 'pwm' 是你在 pubspec.yaml 中定义的项目名称
import 'package:pwm/main.dart';
// 导入你的屏幕以便按类型查找 (可选，但有时有用)
import 'package:pwm/screens/pin_setup_screen.dart';

// **重要:** 对于更复杂的测试，你可能需要设置模拟 (mocks)
// 例如，使用 mockito 或 riverpod 的 override 功能来模拟 SharedPreferences 或 AuthService
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:pwm/providers/auth_providers.dart'; // For overriding

void main() {
  // --- 可选: 测试前的设置 ---
  // 对于需要模拟 SharedPreferences 的测试:
  // setUpAll(() {
  //   // Set SharedPreferences mock defaults before any tests run
  //   // This is essential if your initial providers read from SharedPreferences
  //   SharedPreferences.setMockInitialValues({}); // Example: empty prefs for first launch test
  // });

  testWidgets('App initial launch shows PIN setup screen (smoke test)', (WidgetTester tester) async {
    // ** Arrange **

    // 如果需要覆盖 providers (例如，强制设置 isPinSet 为 false):
    // final container = ProviderContainer(
    //   overrides: [
    //     // Example: Override isPinSetProvider to always return false for this test
    //     isPinSetProvider.overrideWith((ref) async => false),
    //     // 你可能需要覆盖其他依赖项，如 storageServiceProvider 的 FutureProvider
    //     // 来避免在测试中实际执行 Hive 初始化等操作。
    //   ],
    // );

    // ** Act **
    // 构建应用。用 ProviderScope 包裹你的根 Widget (PWMApp)。
    // 如果你使用了上面的 container 进行覆盖，请使用 UncontrolledProviderScope:
    // await tester.pumpWidget(
    //   UncontrolledProviderScope(
    //     container: container,
    //     child: const PWMApp(),
    //   )
    // );
    //
    // 如果不进行覆盖，则直接使用 ProviderScope:
    await tester.pumpWidget(
      const ProviderScope( // 必须包裹 ProviderScope
        child: PWMApp(),      // 使用你的 App Widget: PWMApp
      ),
    );

    // ** Assert **

    // 由于 Provider 初始化（特别是 FutureProvider）可能是异步的，
    // 你可能需要等待它们完成。tester.pumpAndSettle() 会持续触发帧直到没有更多帧计划。
    // 注意：如果存在无限动画或定时器，这可能会超时。
    await tester.pumpAndSettle(); // 等待异步操作和 UI 更新

    // --- 验证初始屏幕 ---
    // 根据你的应用逻辑，在没有设置 PIN 的情况下，
    // 初始屏幕应该是 PinSetupScreen。

    // 1. 验证 PWMApp 本身被渲染了
    expect(find.byType(PWMApp), findsOneWidget, reason: 'The root PWMApp widget should be present.');

    // 2. 验证 PinSetupScreen 被显示了
    //    (这假设你的 AuthState 在测试环境中正确解析为 AuthState.unknown)
    expect(find.byType(PinSetupScreen), findsOneWidget, reason: 'PinSetupScreen should be displayed on initial launch without PIN.');

    // 3. 验证 PinSetupScreen 中的一些关键元素
    expect(find.text('设置主密码'), findsOneWidget, reason: 'The title "设置主密码" should be visible on the setup screen.');

    // 4. 查找 Pinput 组件 (确保已导入 pinput)
    // expect(find.byType(Pinput), findsOneWidget, reason: 'Pinput widget should be present for PIN entry.');

    // 5. 查找创建按钮
    expect(find.widgetWithText(ElevatedButton, '创建密码'), findsOneWidget, reason: 'The "创建密码" button should be visible.');

    // --- 清理掉默认的计数器测试逻辑 ---
    // expect(find.text('0'), findsOneWidget); // 这行会失败
    // expect(find.text('1'), findsNothing); // 这行会失败
    // await tester.tap(find.byIcon(Icons.add)); // 这行会失败
    // await tester.pump();
    // expect(find.text('0'), findsNothing); // 这行会失败
    // expect(find.text('1'), findsOneWidget); // 这行会失败

     print("Widget Test: Initial screen verification completed successfully.");

  });

  // --- 添加更多测试 ---
  // testWidgets('Entering valid PIN during setup navigates correctly', (WidgetTester tester) async {
  //   // 1. Setup: pumpWidget with ProviderScope (possibly with overrides)
  //   // 2. Find Pinput widgets
  //   // 3. Use tester.enterText() to input PIN into Pinput fields
  //   // 4. Find and tap the '创建密码' button
  //   // 5. Use pumpAndSettle() to wait for navigation/state changes
  //   // 6. Assert that PinAuthScreen or MainLayout is now visible
  // });

  // testWidgets('Entering incorrect PIN shows error', (WidgetTester tester) async {
     // 1. Setup: pumpWidget with ProviderScope (override providers to simulate PIN being set)
     // 2. Ensure PinAuthScreen is shown initially
     // 3. Enter an incorrect PIN
     // 4. Tap '解锁' button
     // 5. pumpAndSettle()
     // 6. Assert that an error message is shown (e.g., find.text('PIN 码错误...'))
     // 7. Assert that PinAuthScreen is still visible
  // });
}