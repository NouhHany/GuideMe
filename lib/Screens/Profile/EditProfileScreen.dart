import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/AppLocalizations.dart';

// Country data model
class Country {
  final String name;
  final String code;
  final String dialCode;

  Country({
    required this.name,
    required this.code,
    required this.dialCode,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Country &&
        name == other.name &&
        code == other.code &&
        dialCode == other.dialCode;
  }

  @override
  int get hashCode => Object.hash(name, code, dialCode);
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
          borderRadius: BorderRadius.circular(20),
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

class EditProfileScreen extends StatefulWidget {
  final String? currentName;
  final String? currentEmail;
  final String? currentPhone;

  const EditProfileScreen({
    super.key,
    this.currentName,
    this.currentEmail,
    this.currentPhone,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _currentPasswordError;
  String? _newPasswordError;
  OverlayEntry? _overlayEntry;
  final _storage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<Country> _countries = [
    Country(name: 'Egypt', code: 'EG', dialCode: '+20'),
    Country(name: 'United States', code: 'US', dialCode: '+1'),
    Country(name: 'United Kingdom', code: 'GB', dialCode: '+44'),
    Country(name: 'Saudi Arabia', code: 'SA', dialCode: '+966'),
    Country(name: 'United Arab Emirates', code: 'AE', dialCode: '+971'),
    Country(name: 'Canada', code: 'CA', dialCode: '+1'),
    Country(name: 'Australia', code: 'AU', dialCode: '+61'),
    Country(name: 'India', code: 'IN', dialCode: '+91'),
    Country(name: 'Germany', code: 'DE', dialCode: '+49'),
    Country(name: 'France', code: 'FR', dialCode: '+33'),
    Country(name: 'Italy', code: 'IT', dialCode: '+39'),
    Country(name: 'Japan', code: 'JP', dialCode: '+81'),
    Country(name: 'China', code: 'CN', dialCode: '+86'),
    Country(name: 'Brazil', code: 'BR', dialCode: '+55'),
    Country(name: 'South Africa', code: 'ZA', dialCode: '+27'),
  ];

  late Country _selectedCountry;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName ?? '');
    _emailController = TextEditingController(text: widget.currentEmail ?? '');
    _phoneController = TextEditingController(text: widget.currentPhone ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _selectedCountry = _countries[0];
    _loadUserData();

    _nameController.addListener(() {
      if (_nameError != null && _nameController.text.isNotEmpty) {
        setState(() => _nameError = null);
      }
    });
    _emailController.addListener(() {
      if (_emailError != null && _emailController.text.isNotEmpty) {
        setState(() => _emailError = null);
      }
    });
    _phoneController.addListener(() {
      if (_phoneError != null && _phoneController.text.isNotEmpty) {
        setState(() => _phoneError = null);
      }
    });
    _currentPasswordController.addListener(() {
      if (_currentPasswordError != null && _currentPasswordController.text.isNotEmpty) {
        setState(() => _currentPasswordError = null);
      }
    });
    _newPasswordController.addListener(() {
      if (_newPasswordError != null && _newPasswordController.text.isNotEmpty) {
        setState(() => _newPasswordError = null);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
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

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _nameController.text = data?['name'] ?? widget.currentName ?? '';
            _emailController.text = data?['email'] ?? widget.currentEmail ?? '';
            String? phone = data?['phone'] ?? widget.currentPhone ?? '';
            _phoneController.text = phone ?? '';
            if (phone != null && phone.isNotEmpty) {
              for (var country in _countries) {
                if (phone.startsWith(country.dialCode)) {
                  _selectedCountry = country;
                  _phoneController.text = phone;
                  break;
                }
              }
            } else {
              _phoneController.text = '';
            }
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', _nameController.text.trim());
          await prefs.setString('userEmail', _emailController.text.trim());
          await prefs.setString('userPhone', _phoneController.text.trim());
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessageOverlay(
          AppLocalizations.of(context).translate('failed_to_load_user_data') ?? 'Unable to load user data. Please try again.',
        );
      }
    }
  }

  bool _validatePassword(String password) {
    final RegExp regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!*#@]).{6,}$');
    return regex.hasMatch(password);
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _nameError = _nameController.text.trim().isEmpty
          ? AppLocalizations.of(context).translate('name_required') ?? 'Please enter your name.'
          : null;
      _emailError = _emailController.text.trim().isEmpty
          ? AppLocalizations.of(context).translate('email_required') ?? 'Please enter your email.'
          : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())
          ? AppLocalizations.of(context).translate('invalid_email') ?? 'The email format is incorrect.'
          : null;
      _phoneError = _phoneController.text.trim().isEmpty
          ? AppLocalizations.of(context).translate('phone_required') ?? 'Please enter your phone number.'
          : !RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(_phoneController.text.trim())
          ? AppLocalizations.of(context).translate('invalid_phone') ?? 'The phone number format is incorrect.'
          : null;
      _currentPasswordError = _newPasswordController.text.isNotEmpty && _currentPasswordController.text.isEmpty
          ? AppLocalizations.of(context).translate('current_password_required') ?? 'Please enter your current password.'
          : null;
      _newPasswordError = _newPasswordController.text.isNotEmpty && !_validatePassword(_newPasswordController.text)
          ? AppLocalizations.of(context).translate('weak_password') ??
          'Password must include at least 6 characters, one uppercase letter, one lowercase letter, one number, and one special character (*!@#).'
          : null;
    });

    if (_nameError != null || _emailError != null || _phoneError != null || _currentPasswordError != null || _newPasswordError != null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      if (_newPasswordController.text.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? widget.currentEmail!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);
        if (!mounted) return;
        _showMessageOverlay(
          AppLocalizations.of(context).translate('password_updated') ?? 'Password updated successfully!',
          isError: false,
        );
      }

      await user.updateDisplayName(_nameController.text.trim());
      await user.updateEmail(_emailController.text.trim());

      await _firestore.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', _nameController.text.trim());
      await prefs.setString('userEmail', _emailController.text.trim());
      await prefs.setString('userPhone', _phoneController.text.trim());

      if (!mounted) return;
      _showMessageOverlay(
        AppLocalizations.of(context).translate('profile_updated') ?? 'Profile updated successfully!',
        isError: false,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      String errorMessage = AppLocalizations.of(context).translate('profile_update_failed') ?? 'Unable to update profile. Please try again.';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'wrong-password':
            setState(() {
              _currentPasswordError =
                  AppLocalizations.of(context).translate('wrong_current_password') ?? 'The current password is incorrect.';
            });
            break;
          case 'weak-password':
            setState(() {
              _newPasswordError =
                  AppLocalizations.of(context).translate('weak_password') ?? 'The new password is too weak.';
            });
            break;
          case 'requires-recent-login':
            errorMessage =
                AppLocalizations.of(context).translate('requires_recent_login') ?? 'Please log in again to update your profile.';
            break;
          case 'invalid-email':
            setState(() {
              _emailError = AppLocalizations.of(context).translate('invalid_email') ?? 'The email format is incorrect.';
            });
            break;
          default:
            errorMessage = AppLocalizations.of(context).translate('profile_update_failed') ?? 'Unable to update profile. Please try again.';
        }
      }
      if (errorMessage.isNotEmpty) {
        _showMessageOverlay(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final TextEditingController _resetEmailController = TextEditingController(text: _emailController.text);
    String? _resetEmailError;
    bool _isDialogLoading = false;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context).translate('forgot_password') ?? 'Forgot Password'),
              content: TextField(
                controller: _resetEmailController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('enter_email') ?? 'Enter your email',
                  errorText: _resetEmailError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) {
                  if (_resetEmailError != null && value.isNotEmpty) {
                    setDialogState(() => _resetEmailError = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).translate('cancel') ?? 'Cancel',
                    style: const TextStyle(color: Color(0xFFD4B087)),
                  ),
                ),
                TextButton(
                  onPressed: _isDialogLoading
                      ? null
                      : () async {
                    final email = _resetEmailController.text.trim();
                    if (email.isEmpty) {
                      setDialogState(() {
                        _resetEmailError = AppLocalizations.of(context).translate('email_required') ?? 'Please enter your email.';
                      });
                      return;
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                      setDialogState(() {
                        _resetEmailError = AppLocalizations.of(context).translate('invalid_email') ?? 'The email format is incorrect.';
                      });
                      return;
                    }

                    setDialogState(() {
                      _isDialogLoading = true;
                    });

                    try {
                      await _auth.sendPasswordResetEmail(email: email);
                      if (!mounted) return;
                      _showMessageOverlay(
                        AppLocalizations.of(context).translate('reset_email_sent') ?? 'Password reset email sent! Check your inbox.',
                        isError: false,
                      );
                      Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      _showMessageOverlay(
                        AppLocalizations.of(context).translate('reset_email_failed') ?? 'Unable to send reset email. Please try again.',
                      );
                    } finally {
                      setDialogState(() {
                        _isDialogLoading = false;
                      });
                    }
                  },
                  child: _isDialogLoading
                      ? const CircularProgressIndicator(color: Color(0xFFD4B087))
                      : Text(
                    AppLocalizations.of(context).translate('send') ?? 'Send',
                    style: const TextStyle(color: Color(0xFFD4B087)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('edit_profile') ?? 'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.translate('personal_information') ?? 'Personal Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('name') ?? 'Name',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: localizations.translate('enter_name') ?? 'Enter your name',
                  errorText: _nameError,
                ),
                validator: null,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('email') ?? 'Email',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: localizations.translate('enter_email') ?? 'Enter your email',
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: null,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('phone') ?? 'Phone Number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Country>(
                        value: _selectedCountry,
                        onChanged: (Country? newValue) {
                          if (newValue != null) {
                            setState(() {
                              if (_phoneController.text.isNotEmpty && _phoneController.text.startsWith(_selectedCountry.dialCode)) {
                                String remainingNumber = _phoneController.text.substring(_selectedCountry.dialCode.length).trim();
                                _phoneController.text = '${newValue.dialCode}$remainingNumber';
                              }
                              _selectedCountry = newValue;
                            });
                          }
                        },
                        items: _countries.map((Country country) {
                          return DropdownMenuItem<Country>(
                            value: country,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                '${country.dialCode} (${country.name})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                        isExpanded: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        hintText: localizations.translate('enter_phone') ?? 'Enter your phone number',
                        errorText: _phoneError,
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        if (value.isNotEmpty && value.startsWith(_selectedCountry.dialCode)) {
                          _phoneController.text = value;
                          _phoneController.selection = TextSelection.fromPosition(
                            TextPosition(offset: value.length),
                          );
                        }
                      },
                      validator: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                localizations.translate('change_password') ?? 'Change Password',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('current_password') ?? 'Current Password',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: localizations.translate('enter_current_password') ?? 'Enter your current password',
                  errorText: _currentPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureCurrentPassword,
                validator: null,
              ),
              const SizedBox(height: 16),
              Text(
                localizations.translate('new_password') ?? 'New Password (Optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: localizations.translate('enter_new_password') ?? 'Enter your new password',
                  errorText: _newPasswordError,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureNewPassword,
                validator: null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: Text(
                    localizations.translate('forgot_password') ?? 'Forgot Password?',
                    style: const TextStyle(color: Color(0xFFD4B087)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4B087),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black87)
                      : Text(
                    localizations.translate('save') ?? 'Save',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}