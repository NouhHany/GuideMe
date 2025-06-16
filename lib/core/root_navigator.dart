import 'package:flutter/material.dart';
import 'package:guideme/Screens/Favorites/FavoritesScreen.dart';
import 'package:guideme/Screens/Home/Home%20Screen/HomeScreen.dart';
import 'package:guideme/Screens/Profile/UserProfileScreen.dart';
import 'package:provider/provider.dart';

import '../core/AppLocalizations.dart';
import '../core/AppState.dart';

class RootNavigator extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final String? userPhone;

  const RootNavigator({
    super.key,
    this.userName,
    this.userEmail,
    this.userPhone,
  });

  @override
  _RootNavigatorState createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<RootNavigator> {
  int _selectedIndex = 0;
  late List<Widget> _screens; // Store screens in state to preserve instances

  @override
  void initState() {
    super.initState();
    // Initialize screens once to preserve their state
    _screens = [
      const HomeScreen(),
      const FavoritesScreen(),
      UserProfileScreen(
        userName: widget.userName ?? 'No Name',
        userEmail: widget.userEmail ?? 'No Email',
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens, // Use the same screen instances
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: localizations.translate('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_rounded),
            label: localizations.translate('favorites'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: localizations.translate('profile'),
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFD4B087),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
