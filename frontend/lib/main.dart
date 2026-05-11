import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_router.dart';
import 'core/api_client.dart';
import 'core/local_storage.dart';
import 'providers/agent_kyc_provider.dart';
import 'providers/delivery_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'widgets/phone_frame_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await openHiveBoxes();
  apiClient.initialize();
  runApp(const riverpod.ProviderScope(child: Bitex99App()));
}

class Bitex99App extends riverpod.ConsumerWidget {
  const Bitex99App({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => StorageService()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AgentKycProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Bitex99 Preview',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark(),
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => PhoneFrameWrapper(
                child: MaterialApp.router(
                  title: 'Bitex99',
                  debugShowCheckedModeBanner: false,
                  theme: themeProvider.currentThemeData,
                  darkTheme: AppTheme.darkTheme,
                  routerConfig: router,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
