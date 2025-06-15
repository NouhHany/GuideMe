import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart'; // Ensure this file exists
import 'Screens/Auth/loginpage.dart';
import 'core/AppLocalizations.dart';
import 'core/AppState.dart';
import 'core/root_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  } catch (e, stackTrace) {
    print('Error initializing Firebase: $e');
    print('Stack trace: $stackTrace');
    // Fallback: If initialization fails, proceed without Firestore persistence
  }
  final appState = AppState();
  runApp(ChangeNotifierProvider.value(value: appState, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GuideMe',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            brightness: appState.isDarkMode ? Brightness.dark : Brightness.light,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4B087),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
          ),
          themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(appState.languageCode),
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('ar', 'EG'),
            Locale('fr', 'FR'),
            Locale('uk', 'UA'),
            Locale('de', 'DE'),
            Locale('ru', 'RU'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'token');
      print('Token from FlutterSecureStorage: ${token ?? 'null'}');

      if (token != null) {
        bool isExpired = JwtDecoder.isExpired(token);
        print('Is token expired? $isExpired');
        if (!isExpired) {
          final decodedToken = JwtDecoder.decode(token);
          print('Decoded token claims: $decodedToken');
          setState(() {
            _userName = decodedToken['unique_name'] ?? 'Unknown';
            _userEmail = decodedToken['email'] ?? 'Unknown';
            _isLoading = false;
          });
        } else {
          print('Token is expired, clearing token');
          await storage.delete(key: 'token');
          setState(() => _isLoading = false);
        }
      } else {
        final user = _auth.currentUser;
        print('Firebase current user: ${user?.email ?? 'null'}, UID: ${user?.uid ?? 'null'}');
        if (user != null) {
          setState(() {
            _userName = user.displayName ?? 'Unknown';
            _userEmail = user.email ?? 'Unknown';
            _isLoading = false;
          });
        } else {
          print('No token or Firebase user found');
          setState(() => _isLoading = false);
        }
      }
    } catch (e, stackTrace) {
      print('Error in _checkAuthStatus: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userName != null && _userEmail != null) {
      print('Navigating to RootNavigator with user: $_userName, $_userEmail');
      return RootNavigator(userName: _userName!, userEmail: _userEmail!, userPhone: null);
    }

    print('Navigating to LoginScreen');
    return const LoginScreen();
  }
}