import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'X',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Color(Constants.primaryColor),
          scaffoldBackgroundColor: Color(Constants.backgroundColor),
          colorScheme: ColorScheme.dark(
            primary: Color(Constants.primaryColor),
            secondary: Color(Constants.secondaryColor),
            surface: Color(Constants.surfaceColor),
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait until storage check is done
        if (authProvider.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authProvider.isAuthenticated) {
          return const ChatListScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
