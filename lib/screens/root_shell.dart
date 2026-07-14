// lib/screens/root_shell.dart
//
// Previously the bottom nav only had 2 destinations ("My Binder" /
// "Global Registry") and Daily Tasks / Add Bird / Incubation / Lineage
// were buried as shortcut cards inside the Binder tab. Now every primary
// section has its own tab, so navigation is predictable and nothing is
// nested three taps deep inside a scrolling feed.

import 'package:flutter/material.dart';
import 'collection_screen.dart';
import 'dashboard_screen.dart';
import 'daily_tasks_screen.dart';
import 'global_registry_screen.dart';
import 'encounter_scanner_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onViewCollection: () => _goTo(1),
        onViewTasks: () => _goTo(2),
      ),
      const CollectionScreen(),
      const DailyTasksScreen(),
      const GlobalRegistryScreen(),
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: IndexedStack(index: _index, children: screens),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EncounterScannerScreen()),
            );
          } else {
            _goTo(index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.style_rounded), label: 'Collection'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_rounded), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.public_rounded), label: 'Registry'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Scanner'),
        ],
      ),
    );
  }
}
