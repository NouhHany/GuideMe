import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../Decorations/BackgroundPainter.dart';
import '../../core/root_navigator.dart';
import 'loginpage.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFD4B087),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const RegistrationScreen(),
    );
  }
}

class _MessageOverlay extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  const _MessageOverlay({
    required this.message,
    required this.isError,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.9) : Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final _storage = const FlutterSecureStorage();
  bool _obscureText = true;
  String? _passwordError;
  String? _emailError;
  String? _usernameError;
  String? _phoneError;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailError != null && _emailController.text.isNotEmpty) {
        setState(() => _emailError = null);
      }
    });
    _passwordController.addListener(() {
      if (_passwordError != null && _passwordController.text.isNotEmpty) {
        setState(() => _passwordError = null);
      }
    });
    _usernameController.addListener(() {
      if (_usernameError != null && _usernameController.text.isNotEmpty) {
        setState(() => _usernameError = null);
      }
    });
    _phoneController.addListener(() {
      if (_phoneError != null && _phoneController.text.isNotEmpty) {
        setState(() => _phoneError = null);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _googleSignIn.disconnect();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showMessageOverlay(String message, {bool isError = true}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: _MessageOverlay(
          message: message,
          isError: isError,
          onDismiss: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Timer(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  bool _validatePassword(String password) {
    final RegExp regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!*#@]).{6,}$');
    return regex.hasMatch(password);
  }

  Future<void> _register() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String username = _usernameController.text.trim();
    final String phone = _phoneController.text.trim();

    setState(() {
      _emailError = email.isEmpty ? 'Please enter your email.' : null;
      _passwordError = password.isEmpty ? 'Please enter your password.' : null;
      _usernameError = username.isEmpty ? 'Please enter your username.' : null;
      _phoneError = phone.isEmpty ? 'Please enter your phone number.' : null;
    });

    if (_emailError != null || _passwordError != null || _usernameError != null || _phoneError != null) {
      return;
    }

    if (!_validatePassword(password)) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters containing : UPPERCASE , lowercase , Number, and (*!@#).';
      });
      return;
    }

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;

      if (user != null) {
        print('User registered: ${user.email}, UID: ${user.uid}');

        try {
          await user.updateDisplayName(username);
          await user.reload();
          print('Display name updated to: ${user.displayName}');
        } catch (e) {
          print('Error updating display name: $e');
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', username);
          await prefs.setString('userEmail', email);
          await prefs.setString('userPhone', phone);
          print('User data saved to SharedPreferences');
        } catch (e) {
          print('Error saving to SharedPreferences: $e');
        }

        if (!mounted) return;
        _showMessageOverlay('Registration completed successfully!', isError: false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RootNavigator(
                userName: username,
                userEmail: email,
                userPhone: phone,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      if (!mounted) return;
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already in use. Try logging in or use a different email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email format is not correct. Please check and try again.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak. Please use a stronger password.';
          break;
        default:
          errorMessage = 'Unable to register. Please try again later.';
      }
      _showMessageOverlay(errorMessage);
    } catch (e, stackTrace) {
      print('Unexpected error during registration: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      _showMessageOverlay('An unexpected issue occurred. Please try again.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('Google Sign-In canceled by user');
        if (!mounted) return;
        _showMessageOverlay('Google Sign-In was canceled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      try {
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        if (user != null) {
          print('Google Sign-In successful: ${user.email}, UID: ${user.uid}');

          final prefs = await SharedPreferences.getInstance();
          final String name = user.displayName ?? googleUser.displayName ?? '';
          await prefs.setString('userName', name);
          await prefs.setString('userEmail', user.email ?? googleUser.email ?? '');
          await prefs.setString('userPhone', user.phoneNumber ?? '');

          if (!mounted) return;
          _showMessageOverlay('Signed in with Google successfully!', isError: false);

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => RootNavigator(
                  userName: name,
                  userEmail: user.email ?? googleUser.email ?? '',
                  userPhone: user.phoneNumber,
                ),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        print('FirebaseAuthException during sign-in: ${e.code} - ${e.message}');
        if (e.code == 'account-exists-with-different-credential') {
          final String email = googleUser.email;
          final List<String> signInMethods = await _auth.fetchSignInMethodsForEmail(email);

          if (signInMethods.contains('password')) {
            _showMessageOverlay('This email is linked to an account. Please sign in with your email and password.');
          } else if (signInMethods.isNotEmpty) {
            final User? currentUser = _auth.currentUser;
            if (currentUser != null) {
              await currentUser.linkWithCredential(credential);
              print('Google account linked successfully');
              if (!mounted) return;
              _showMessageOverlay('Google account linked successfully!', isError: false);
            } else {
              _showMessageOverlay('Please sign in with your existing method first.');
            }
          }
        } else {
          if (!mounted) return;
          _showMessageOverlay('Unable to sign in with Google. Please try again.');
        }
      }
    } catch (error) {
      print('Google Sign-In error: $error');
      if (!mounted) return;
      _showMessageOverlay('An issue occurred with Google Sign-In. Please try again.');
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      if (!await SignInWithApple.isAvailable()) {
        print('Apple Sign-In is not available on this platform.');
        if (!mounted) return;
        _showMessageOverlay('Apple Sign-In is not available on this device.');
        return;
      }

      final webAuthOptions = Platform.isAndroid
          ? WebAuthenticationOptions(
        clientId: 'com.example.yourapp',
        redirectUri: Uri.parse('https://your-redirect-uri.com/callback'),
      )
          : null;

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webAuthOptions,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);
      final User? user = userCredential.user;

      if (user != null) {
        print('Apple Sign-In successful: ${user.email}, UID: ${user.uid}');

        final prefs = await SharedPreferences.getInstance();
        final String displayName = credential.givenName ?? user.displayName ?? '';
        await prefs.setString('userName', displayName);
        await prefs.setString('userEmail', user.email ?? credential.email ?? '');
        await prefs.setString('userPhone', user.phoneNumber ?? '');

        if (!mounted) return;
        _showMessageOverlay('Signed in with Apple successfully!', isError: false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RootNavigator(
                userName: displayName,
                userEmail: user.email ?? credential.email ?? '',
                userPhone: user.phoneNumber,
              ),
            ),
          );
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      print('Apple Sign-In authorization error: ${e.code} - ${e.message}');
      if (!mounted) return;
      _showMessageOverlay('Unable to sign in with Apple. Please try again.');
    } catch (e) {
      print('Unexpected error during Apple Sign-In: $e');
      if (!mounted) return;
      _showMessageOverlay('An issue occurred with Apple Sign-In. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const SizedBox.expand(child: BackgroundPainter()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: MediaQuery.of(context).size.width < 600
                    ? MediaQuery.of(context).size.width * 0.9
                    : 400,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Text(
                            'Welcome to GuideMe',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 0.3
                                ..color = Colors.black,
                            ),
                          ),
                          Text(
                            'Welcome to GuideMe',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4B087),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: Colors.white60),
                          errorText: _usernameError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          errorMaxLines: 2,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _usernameError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _usernameError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: Colors.white60),
                          errorText: _emailError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          errorMaxLines: 2,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _emailError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _emailError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: InputDecoration(
                          labelText: 'Phone',
                          labelStyle: const TextStyle(color: Colors.white60),
                          errorText: _phoneError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          errorMaxLines: 2,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _phoneError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _phoneError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white60),
                          errorText: _passwordError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          errorMaxLines: 3,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _passwordError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: _passwordError != null ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility : Icons.visibility_off,
                              color: Colors.white60,
                            ),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        obscureText: _obscureText,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4B087),
                          minimumSize: const Size(double.infinity, 50),

                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          Text(
                            'OR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 0.2
                                ..color = Colors.black,
                            ),
                          ),
                          const Text(
                            'OR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: Image.asset(
                              'assets/images/logo/google.png',
                              height: 24,
                            ),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(color: Colors.black, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),

                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Already have an account? Log in',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}