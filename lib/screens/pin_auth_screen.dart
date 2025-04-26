import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_providers.dart';

class PinAuthScreen extends ConsumerStatefulWidget {
  const PinAuthScreen({super.key});

  @override
  ConsumerState<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends ConsumerState<PinAuthScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      final pin = _pinController.text;
      final authNotifier = ref.read(authStateProvider.notifier);
      final success = await authNotifier.login(pin);

      if (!success && mounted) {
        setState(() {
          _errorMessage = 'PIN 码错误，请重试。';
          _pinController.clear(); // Clear input on error
        });
      }
      // If successful, the authStateProvider change will trigger
      // the main listener to navigate to the main layout.
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
      appBar: AppBar(title: const Text('验证主密码')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '请输入 6 位数字主密码',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Pinput(
                  controller: _pinController,
                  length: 6,
                  obscureText: true,
                  autofocus: true,
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
                   // Trigger verification on completion
                   onCompleted: (pin) => _verifyPin(),
                   validator: (s) {
                      if (s == null || s.length != 6) {
                        return '请输入 6 位密码';
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
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _verifyPin,
                        child: const Text('解锁'),
                      ),
                 // TODO: Add Forgot PIN functionality? (Would require data reset or recovery mechanism)
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
    super.dispose();
  }
}