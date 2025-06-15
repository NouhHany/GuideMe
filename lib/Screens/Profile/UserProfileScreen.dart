import 'package:flutter/material.dart';
import 'package:guideme/Screens/Auth/loginpage.dart';
import 'package:guideme/Screens/Favorites/FavoritesScreen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/AppLocalizations.dart';
import '../../core/AppState.dart';
import 'EditProfileScreen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userLocation;

  const UserProfileScreen({
    super.key,
    this.userName,
    this.userEmail,
    this.userLocation,
    this.userPhone,
  });

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool notificationsEnabled = true;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _userName = data?['name'] ?? prefs.getString('userName') ?? widget.userName ?? 'Unknown';
            _userEmail = data?['email'] ?? prefs.getString('userEmail') ?? widget.userEmail ?? 'No email';
            _userPhone = data?['phone'] ?? prefs.getString('userPhone') ?? widget.userPhone ?? '';
          });

          await prefs.setString('userName', _userName!.trim());
          await prefs.setString('userEmail', _userEmail!.trim());
          await prefs.setString('userPhone', _userPhone!.trim());
        } else {
          setState(() {
            _userName = prefs.getString('userName') ?? widget.userName ?? 'Unknown';
            _userEmail = prefs.getString('userEmail') ?? widget.userEmail ?? 'No email';
            _userPhone = prefs.getString('userPhone') ?? widget.userPhone ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('failed_to_load_user_data') ?? 'Failed to load user data: $e',
            ),
          ),
        );
      }
      setState(() {
        _userName = prefs.getString('userName') ?? widget.userName ?? 'Unknown';
        _userEmail = prefs.getString('userEmail') ?? widget.userEmail ?? 'No email';
        _userPhone = prefs.getString('userPhone') ?? widget.userPhone ?? '';
      });
    }
  }

  void _showLogoutConfirmation() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('logout_confirmation') ?? 'Logout Confirmation'),
          content: Text(localizations.translate('logout_question') ?? 'Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                localizations.translate('cancel') ?? 'Cancel',
                style: TextStyle(color: Color(0xFFD4B087)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
              child: Text(
                localizations.translate('logout') ?? 'Logout',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  String _normalizeLanguageCode(String code) {
    if (code.startsWith('en')) return 'en';
    if (code.startsWith('ar')) return 'ar';
    if (code.startsWith('fr')) return 'fr';
    if (code.startsWith('uk')) return 'uk';
    if (code.startsWith('de')) return 'de';
    if (code.startsWith('ru')) return 'ru';
    return 'en';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context);

    final displayName = _userName ?? widget.userName ?? 'Unknown';
    final displayEmail = _userEmail ?? widget.userEmail ?? 'No email';
    final displayPhone = _userPhone ?? widget.userPhone ?? '';

    final normalizedLanguageCode = _normalizeLanguageCode(appState.languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('Account') ?? 'Account',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            /*Text(
              displayEmail,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            Text(
              displayPhone.isNotEmpty ? displayPhone : localizations.translate('no_phone') ?? 'No phone number',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),*/
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(
                        currentName: displayName,
                        currentEmail: displayEmail,
                        currentPhone: displayPhone,
                      ),
                    ),
                  ).then((_) {
                    _loadUserData();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4B087),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                label: Text(
                  localizations.translate('edit_profile') ?? 'Edit Profile',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.favorite, color: Color(0xFFD4B087)),
              title: Text(localizations.translate('view_favorites') ?? 'View Favorites'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Color(0xFFD4B087)),
              title: Text(localizations.translate('dark_mode') ?? 'Dark Mode'),
              trailing: Switch(
                value: appState.isDarkMode,
                onChanged: (value) => appState.toggleTheme(value),
                activeColor: const Color(0xFFD4B087),
                thumbColor: WidgetStateProperty.all(const Color(0xFFD4B087)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFFD4B087)),
              title: Text(localizations.translate('language') ?? 'Language'),
              trailing: DropdownButton<String>(
                value: normalizedLanguageCode,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    appState.setLanguageCode(newValue);
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                  DropdownMenuItem(value: 'uk', child: Text('Українська')),
                  DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                  DropdownMenuItem(value: 'ru', child: Text('Русский')),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications, color: Color(0xFFD4B087)),
              title: Text(localizations.translate('notifications') ?? 'Notifications'),
              trailing: Switch(
                value: notificationsEnabled,
                onChanged: (value) => setState(() => notificationsEnabled = value),
                activeColor: const Color(0xFFD4B087),
                thumbColor: WidgetStateProperty.all(const Color(0xFFD4B087)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info, color: Color(0xFFD4B087)),
              title: Text(localizations.translate('about_app') ?? 'About App'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'GuideMe',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2025 Dropout',
                );
              },
            ),
            const Divider(),
            Center(
              child: ElevatedButton.icon(
                onPressed: _showLogoutConfirmation,
                icon: const Icon(Icons.logout),
                label: Text(localizations.translate('logout') ?? 'Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}