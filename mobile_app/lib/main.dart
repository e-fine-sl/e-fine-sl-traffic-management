import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; 
import 'screens/splash/splash_screen.dart';
import 'services/theme_manager.dart';
import 'services/notification_service.dart';
import 'config/app_constants.dart';
import 'widgets/interaction_listener.dart';
import 'screens/auth/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await NotificationService().init();

  runApp(
    
   EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')], 
      
      path: 'assets/translations', 
     
      fallbackLocale: const Locale('en'), 
      
      child: const EFineApp(),
    ),
  );
}

class EFineApp extends StatelessWidget {
  const EFineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'e-Fine SL',
          debugShowCheckedModeBanner: false,
         
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale, 
          
          themeMode: mode,
          navigatorKey: navigatorKey, // Added for global navigation support
          routes: {
            '/login': (context) => const LoginScreen(),
          },
          theme: ThemeData(
            primaryColor: AppColors.primaryGreenDark,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen, primary: AppColors.primaryGreenDark),
            useMaterial3: true,
            fontFamily: 'Poppins',
            scaffoldBackgroundColor: AppColors.background,
            cardColor: AppColors.cardWhite,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.primaryGreenDark,
              foregroundColor: Colors.white,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              selectedItemColor: AppColors.primaryGreenDark,
              unselectedItemColor: Colors.grey,
              backgroundColor: AppColors.cardWhite,
              elevation: 10,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
             primaryColor: AppColors.primaryGreenDark,
             scaffoldBackgroundColor: const Color(0xFF121212),
             cardColor: const Color(0xFF1E1E1E),
             colorScheme: const ColorScheme.dark(
               primary: AppColors.primaryGreenDark,
               secondary: AppColors.primaryGreenLight,
               surface: Color(0xFF1E1E1E),
               onSurface: Colors.white,
             ),
             appBarTheme: const AppBarTheme(
               backgroundColor: AppColors.primaryGreenDark,
               foregroundColor: Colors.white,
             ),
             inputDecorationTheme: InputDecorationTheme(
               filled: true,
               fillColor: const Color(0xFF2C2C2C),
               labelStyle: const TextStyle(color: Colors.white70),
               hintStyle: const TextStyle(color: Colors.white38),
               prefixIconColor: Colors.white60,
               suffixIconColor: Colors.white60,
               border: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
               ),
               enabledBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
               ),
               focusedBorder: OutlineInputBorder(
                 borderRadius: BorderRadius.circular(12),
                 borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
               ),
             ),
             cardTheme: CardThemeData(
               color: const Color(0xFF1E1E1E),
               elevation: 2,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
             bottomNavigationBarTheme: const BottomNavigationBarThemeData(
               selectedItemColor: AppColors.primaryGreenLight,
               unselectedItemColor: Colors.grey,
               backgroundColor: Color(0xFF1E1E1E),
               elevation: 0,
             ),
             textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Poppins'),
          ),
          home: const SplashScreen(),
          builder: (context, child) {
            return InteractionListener(
              navigatorKey: navigatorKey,
              child: child!,
            );
          },
        );
      }
    );
  }
}