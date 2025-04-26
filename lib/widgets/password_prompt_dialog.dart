import 'package:flutter/material.dart';

/// 一个提示用户输入单个密码的对话框。
/// 如果确认，则返回输入的密码 String，否则返回 null。
Future<String?> showPasswordPromptDialog({
  required BuildContext context,
  required String title,
  String hintText = '请输入密码',
  String confirmButtonText = '确认',
}) async {
  final TextEditingController passwordController = TextEditingController();
  // 使用 GlobalKey 作为对话框中 Form 的键
  final formKey = GlobalKey<FormState>();
  // 用于密码可见性的状态变量，由 StatefulBuilder 管理
  bool isPasswordVisible = false;

  return showDialog<String>(
    context: context,
    // 防止通过点击外部或后退按钮来关闭，而无需显式操作
    barrierDismissible: false,
    builder: (BuildContext context) {
      // StatefulBuilder 允许专门在对话框的内容中管理状态 (如密码可见性)，
      // 而无需 StatefulWidget。
      return StatefulBuilder(
        builder: (context, setStateDialog) { // 为内部 setState 使用不同的名称
          return AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey, // 将键与 Form 关联
              child: TextFormField(
                controller: passwordController,
                obscureText: !isPasswordVisible, // 根据状态控制遮蔽
                autofocus: true, // 在对话框打开时自动聚焦该字段
                decoration: InputDecoration(
                  labelText: hintText,
                  // 用于切换密码可见性的后缀图标
                  suffixIcon: IconButton(
                    icon: Icon(
                      // 根据可见性状态更改图标
                      isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20, // 如果需要，调整大小
                    ),
                    tooltip: isPasswordVisible ? '隐藏密码' : '显示密码',
                    onPressed: () {
                      // 使用来自 StatefulBuilder 的 setState 仅更新对话框的内容
                      setStateDialog(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  // 基本验证：密码不能为空
                  if (value == null || value.isEmpty) {
                    return '密码不能为空';
                  }
                  // 可选：如果需要，在此处添加更复杂的验证规则
                  // 例如，最小长度检查
                  // if (value.length < 6) {
                  //   return '密码至少需要 6 位';
                  // }
                  return null; // 如果验证通过，则返回 null
                },
                // 可选：如果需要，更改键盘类型 (例如，对于 PIN)
                // keyboardType: TextInputType.number,
              ),
            ),
            actions: <Widget>[
              // 取消按钮
              TextButton(
                child: const Text('取消'),
                onPressed: () {
                  // 关闭对话框并返回 null (表示取消)
                  Navigator.of(context).pop(null);
                },
              ),
              // 确认按钮
              ElevatedButton(
                child: Text(confirmButtonText),
                onPressed: () {
                  // 使用 GlobalKey 验证表单
                  if (formKey.currentState!.validate()) {
                    // 如果验证通过，则关闭对话框并返回输入的密码
                    Navigator.of(context).pop(passwordController.text);
                  }
                  // 如果验证失败，对话框将保持打开状态，显示错误消息
                },
              ),
            ],
          );
        },
      );
    },
  );
}


/// 一个提示用户设置和确认密码的对话框。
/// 如果确认并且密码匹配，则返回验证后的密码 String，否则返回 null。
Future<String?> showSetPasswordDialog({
  required BuildContext context,
  required String title,
  String passwordHintText = '设置密码',
  String confirmHintText = '确认密码',
  String confirmButtonText = '确认',
}) async {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  // 整个表单的键
  final formKey = GlobalKey<FormState>();
  // 专门用于确认字段以触发其验证的单独键
  final confirmPasswordKey = GlobalKey<FormFieldState<String>>();
  // 用于可见性的状态变量，由 StatefulBuilder 管理
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  return showDialog<String>(
    context: context,
    barrierDismissible: false, // 防止意外关闭
    builder: (BuildContext context) {
      // 使用 StatefulBuilder 管理对话框中的可见性状态
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(title),
            content: Form(
              key: formKey, // 将键与 Form 关联
              child: Column(
                mainAxisSize: MainAxisSize.min, // 保持对话框大小受限
                children: [
                  // 密码字段
                  TextFormField(
                    controller: passwordController,
                    obscureText: !isPasswordVisible,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: passwordHintText,
                      suffixIcon: IconButton(
                        icon: Icon(isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        tooltip: isPasswordVisible ? '隐藏密码' : '显示密码',
                        // 使用内部 setState 仅更新此对话框的状态
                        onPressed: () => setStateDialog(() => isPasswordVisible = !isPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return '密码不能为空';
                      // 可选：在此处添加复杂性/长度规则
                      // if (value.length < 8) return '密码至少需要8位';

                      // --- 修复：仅验证确认字段 ---
                      // 如果确认字段已经有文本，则触发其验证
                      // 以检查它是否与可能已更改的密码匹配。
                      if (confirmPasswordController.text.isNotEmpty) {
                          // 仅在确认字段的状态上调用 validate()
                          confirmPasswordKey.currentState?.validate();
                      }
                      // --- 结束修复 ---
                      return null; // 如果非空 (并满足其他规则)，则密码字段本身有效
                    },
                  ),
                  const SizedBox(height: 16), // 字段之间的间距
                  // 确认密码字段
                  TextFormField(
                    key: confirmPasswordKey, // 在此处分配特定键
                    controller: confirmPasswordController,
                    obscureText: !isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: confirmHintText,
                       suffixIcon: IconButton(
                        icon: Icon(isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                         tooltip: isConfirmPasswordVisible ? '隐藏密码' : '显示密码',
                        onPressed: () => setStateDialog(() => isConfirmPasswordVisible = !isConfirmPasswordVisible),
                      ),
                    ),
                    validator: (value) {
                      // 确认字段的验证
                      if (value == null || value.isEmpty) return '请确认密码';
                      if (value != passwordController.text) return '两次输入的密码不一致';
                      return null; // 如果验证通过，则返回 null
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              // 取消按钮
              TextButton(
                child: const Text('取消'),
                onPressed: () => Navigator.of(context).pop(null), // 在取消时返回 null
              ),
              // 确认按钮
              ElevatedButton(
                child: Text(confirmButtonText),
                onPressed: () {
                  // 在按下确认按钮时验证整个表单
                  if (formKey.currentState!.validate()) {
                    // 如果两个字段都有效且匹配，则返回密码
                    Navigator.of(context).pop(passwordController.text);
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
