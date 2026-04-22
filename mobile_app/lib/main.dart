import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; 
import 'screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/police_locale_service.dart';
import 'widgets/interaction_listener.dart';
import 'screens/auth/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/sos_service.dart';
import 'providers/theme_provider.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase for FCM
  await EasyLocalization.ensureInitialized();
  await NotificationService().init();
  await PoliceLocaleService.instance.init();
  SosService.setupFCMListeners(); // Start listening for SOS alerts

  runApp(
    
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')], 
      path: 'assets/translations', 
      fallbackLocale: const Locale('en'), 
      child: ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const EFineApp(),
      ),
    ),
  );
}

class EFineApp extends StatelessWidget {
  const EFineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'e-Fine SL',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale, 
          themeMode: themeProvider.themeMode,
          navigatorKey: navigatorKey,
          routes: {
            '/login': (context) => const LoginScreen(),
          },
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          home: const SplashScreen(),
          builder: (context, child) {
            return InteractionListener(
              navigatorKey: navigatorKey,
              child: child!,
            );
          },
        );
      },
    );
  }
}