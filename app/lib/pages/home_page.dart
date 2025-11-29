import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/l10n/app_localizations.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../services/wallet_service.dart';
import '../services/ble_service.dart';
import '../widgets/booking_card.dart';
import 'booking_page.dart';
import 'map_page.dart';
import 'all_tickets_page.dart';
import 'ticket_details_page.dart';
import 'qr_code_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    // HomePage is now just a wrapper that uses HomePageContent
    // This maintains backward compatibility if needed
    return const HomePageContent();
  }
}

// Content-only version for bottom navigation
class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final BookingService _bookingService = BookingService();
  final WalletService _walletService = WalletService();
  List<Booking> _activeBookings = [];
  double _walletBalance = 0.0;
  int _totalActiveTickets = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await _bookingService.getActiveBookings();
      double balance = 0.0;
      try {
        final wallet = await _walletService.getWallet();
        balance = wallet.balance;
      } catch (e) {
        // Wallet might not exist yet
      }

      if (mounted) {
        setState(() {
          _activeBookings = bookings;
          _walletBalance = balance;
          _totalActiveTickets = bookings.length;
          _isLoading = false;
        });
        
        // Update BLE service with new active tickets
        try {
          final bleService = Provider.of<BLEService>(context, listen: false);
          bleService.updateActiveTickets();
        } catch (e) {
          // BLE service might not be initialized yet
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${localizations?.errorLoadingData ?? 'Error loading data'}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cache localizations to avoid repeated lookups
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
            tooltip: 'View Map',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Section
                    _buildOverviewSection(localizations),
                    const SizedBox(height: 24),
                    // Active Tickets Section
                    _buildActiveTicketsSection(localizations),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BookingPage()),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add),
        label: Text(localizations?.bookTicket ?? 'Book Ticket'),
      ),
    );
  }

  Widget _buildOverviewSection(AppLocalizations? localizations) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations?.overview ?? 'Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.account_balance_wallet,
                    label: localizations?.walletBalance ?? 'Wallet Balance',
                    value: '€${_walletBalance.toStringAsFixed(2)}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.confirmation_number,
                    label: localizations?.activeTickets ?? 'Active Tickets',
                    value: '$_totalActiveTickets',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTicketsSection(AppLocalizations? localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              localizations?.activeTickets ?? 'Active Tickets',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_activeBookings.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTicketsPage(),
                    ),
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(localizations?.viewAll ?? 'View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_activeBookings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.noActiveTickets ?? 'No active tickets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations?.bookFirstTicket ?? 'Book your first ticket to get started',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ..._activeBookings
              .take(5)
              .map(
                (booking) => Padding(
                  key: ValueKey(booking.id), // Add key for better performance
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookingCard(
                    booking: booking,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TicketDetailsPage(booking: booking),
                        ),
                      );
                    },
                    onQRTap: booking.qrCode != null
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QRCodePage(initialBooking: booking),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ),
        if (_activeBookings.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTicketsPage(),
                    ),
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text('${localizations?.viewMore ?? 'View More'} (${_activeBookings.length - 5} more)'),
              ),
            ),
          ),
      ],
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

