import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'home_page.dart';
import 'booking_page.dart';
import 'wallet_page.dart';
import 'more_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Cache pages with keys for better performance
  final List<Widget> _pages = [
    const HomePageContent(key: ValueKey('home')),
    const BookingPage(key: ValueKey('booking')),
    const WalletPage(key: ValueKey('wallet')),
    const MorePage(key: ValueKey('more')),
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: localizations?.home ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.confirmation_number_outlined),
            selectedIcon: const Icon(Icons.confirmation_number),
            label: localizations?.book ?? 'Book',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: localizations?.wallet ?? 'Wallet',
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_outlined),
            selectedIcon: const Icon(Icons.more_horiz),
            label: localizations?.more ?? 'More',
          ),
        ],
      ),
    );
  }
}
