import 'package:flutter/material.dart';

import '../calls/calls_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../ring/ring_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const CallsScreen(),
      const SizedBox.shrink(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index == 2 ? 0 : _index, children: pages),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RingScreen()),
        ),
        shape: const CircleBorder(),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active_outlined, size: 28),
            SizedBox(height: 2),
            Text('RING', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RingScreen()),
            );
            return;
          }
          setState(() => _index = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'RING',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
