import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/config/theme.dart';
import 'package:policysquare/providers/chat_provider.dart';
import 'package:policysquare/providers/commercial_provider.dart';
import 'package:policysquare/providers/inspection_provider.dart';
import 'package:policysquare/screens/auth/login_screen.dart';
import 'package:policysquare/screens/main_screen.dart';
import 'package:policysquare/screens/commercial/inspection_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PolicySquareApp());
}

class PolicySquareApp extends StatefulWidget {
  const PolicySquareApp({super.key});

  @override
  State<PolicySquareApp> createState() => _PolicySquareAppState();
}

class _PolicySquareAppState extends State<PolicySquareApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString('mobile_number');
    if (mobile != null) {
      setState(() => _isLoggedIn = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CommercialProvider();
            provider.loadMobileNumber();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
      ],
      child: MaterialApp(
        title: 'PolicySquare',
        theme: AppTheme.lightTheme,
        // Define routes for cleaner navigation
        initialRoute: _isLoggedIn ? '/inspection' : '/login',
        routes: {
          '/': (context) =>
              _isLoggedIn ? const InspectionSelectionScreen() : const LoginScreen(),
          '/login': (context) => const LoginScreen(),
          '/inspection': (context) => const InspectionSelectionScreen(),
          '/home': (context) => const InspectionSelectionScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
