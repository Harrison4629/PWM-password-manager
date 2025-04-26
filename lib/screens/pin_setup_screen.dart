import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_providers.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final bool isChangePinMode; // Add flag for changing PIN vs initial setup
  const PinSetupScreen({super.key, this.isChangePinMode = false});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _oldPinController = TextEditingController(); // Only used if isChangePinMode is true

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      final newPin = _pinController.text;
      final authNotifier = ref.read(authStateProvider.notifier);

      if (widget.isChangePinMode) {
        final oldPin = _oldPinController.text;
         // Call changePin method in AuthStateNotifier
        final success = await authNotifier.changePin(oldPin, newPin);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN 更改成功！请重新登录。')));
          // Pop back or navigate to login - auth state change handles redirection
          if (mounted) Navigator.of(context).pop();
        } else {
          setState(() {
            _errorMessage = '旧 PIN 码验证失败或更改出错。';
          });
        }
      } else {
         // Initial Setup
        await authNotifier.setupPin(newPin);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('主密码设置成功！')));
        // Auth state will change, triggering rebuild in main.dart to show login
      }
    } else {
      setState(() {
        _errorMessage = '请检查输入';
      });
    }

    if (mounted) {
       setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isChangePinMode ? '更改主密码' : '设置主密码'),
        automaticallyImplyLeading: widget.isChangePinMode, // Show back button only when changing
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isChangePinMode
                      ? '请输入旧密码和新密码'
                      : '创建一个 6 位数字主密码',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                if (widget.isChangePinMode) ...[
                  const Text('旧的 6 位密码:'),
                  const SizedBox(height: 8),
                  Pinput(
                    controller: _oldPinController,
                    length: 6,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyDecorationWith(
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    submittedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration?.copyWith(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                    validator: (s) {
                      if (s == null || s.length != 6) {
                        return '请输入 6 位旧密码';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                const Text('新的 6 位密码:'),
                const SizedBox(height: 8),
                Pinput(
                  controller: _pinController,
                  length: 6,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(color: Theme.of(context).colorScheme.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  submittedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration?.copyWith(
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                  validator: (s) {
                    if (s == null || s.length != 6) {
                      return '请输入 6 位新密码';
                    }
                    // Check if it matches confirmation only if confirm field is used
                    if (_confirmPinController.text.isNotEmpty && s != _confirmPinController.text) {
                       return '两次输入的密码不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text('确认新密码:'),
                const SizedBox(height: 8),
                 Pinput(
                    controller: _confirmPinController,
                    length: 6,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    defaultPinTheme: defaultPinTheme,
                     focusedPinTheme: defaultPinTheme.copyDecorationWith(
                        border: Border.all(color: Theme.of(context).colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                     ),
                     submittedPinTheme: defaultPinTheme.copyWith(
                       decoration: defaultPinTheme.decoration?.copyWith(
                         color: Theme.of(context).colorScheme.primaryContainer,
                       ),
                     ),
                    validator: (s) {
                      if (s == null || s.length != 6) {
                        return '请确认新密码';
                      }
                      if (s != _pinController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 30),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submitPin,
                        child: Text(widget.isChangePinMode ? '确认更改' : '创建密码'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _oldPinController.dispose();
    super.dispose();
  }
}