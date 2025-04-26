import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'models/password_entry.dart';
import 'providers/auth_providers.dart';
import 'providers/password_providers.dart';
import 'screens/main_layout.dart';
import 'screens/pin_auth_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  if (!Hive.isAdapterRegistered(kPasswordEntryTypeId)) {
      Hive.registerAdapter(PasswordEntryAdapter());
  }
  runApp( const ProviderScope( child: PWMApp(),), );
}

class PWMApp extends ConsumerWidget {
  const PWMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageAsyncValue = ref.watch(storageServiceProvider);
    final authState = ref.watch(authStateProvider);

    return storageAsyncValue.when(
       data: (storageService) {
          return MaterialApp(
             title: 'PWM - 密码管理器',
             theme: appTheme,
             debugShowCheckedModeBanner: false,
             home: _buildHomeScreen(authState),
          );
       },
       loading: () => MaterialApp(
          theme: appTheme,
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("storage_loading")))),
       ),
       error: (error, stackTrace) => MaterialApp(
          theme: appTheme,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
             body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '应用初始化失败。\n请尝试重启应用。\n错误: $error',
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.red[700]),
                  ),
                ),
             ),
          ),
       ),
    );
  }

  Widget _buildHomeScreen(AuthState authState) {
     switch (authState) {
       case AuthState.authenticated:
         return const MainLayout();
       case AuthState.unauthenticated:
         return const PinAuthScreen();
       case AuthState.checking:
          return const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("auth_checking"))));
       case AuthState.unknown:
       return const PinSetupScreen();
     }
   }
}
