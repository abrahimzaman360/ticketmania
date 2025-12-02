import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking.dart' as models;
import '../widgets/booking_card.dart';
import '../widgets/offline_indicator.dart';
import '../providers/booking_providers.dart';
import '../providers/ble_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/service_providers.dart';
import 'map_page.dart';
import 'all_tickets_page.dart';
import 'ticket_details_page.dart';

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
class HomePageContent extends ConsumerStatefulWidget {
  const HomePageContent({super.key});

  @override
  ConsumerState<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends ConsumerState<HomePageContent> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Update BLE service when bookings change
    final bookingsAsync = ref.watch(activeBookingsProvider);
    bookingsAsync.whenData((bookings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            final bleService = ref.read(bleServiceProvider);
            bleService.updateActiveTickets().catchError((e) {
              debugPrint('Error updating BLE service: $e');
            });
          } catch (e) {
            debugPrint('Error accessing BLE service: $e');
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Cache localizations to avoid repeated lookups
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.appTitle ?? 'Ticket Mania'),
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
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeBookingsProvider);
          ref.invalidate(walletBalanceProvider);
          // Wait for providers to refresh
          await Future.delayed(const Duration(milliseconds: 100));
        },
        child: ref
            .watch(activeBookingsProvider)
            .when(
              data: (bookings) {
                // Watch wallet balance provider separately
                final walletBalanceAsync = ref.watch(walletBalanceProvider);

                return walletBalanceAsync.when(
                  data: (walletBalance) {
                    // Both providers have data - show full content
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview Section
                          _buildOverviewSection(
                            localizations,
                            bookings.length,
                            walletBalance,
                          ),
                          const SizedBox(height: 24),
                          // Active Tickets Section
                          _buildActiveTicketsSection(localizations, bookings),
                        ],
                      ),
                    );
                  },
                  loading: () {
                    // Bookings loaded but wallet still loading - show bookings with loading wallet
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview Section with loading wallet
                          _buildOverviewSection(
                            localizations,
                            bookings.length,
                            0.0,
                          ),
                          const SizedBox(height: 24),
                          // Active Tickets Section
                          _buildActiveTicketsSection(localizations, bookings),
                        ],
                      ),
                    );
                  },
                  error: (error, stack) {
                    // Bookings loaded but wallet error - show bookings with 0 balance
                    debugPrint('Error loading wallet balance: $error');
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overview Section with 0 balance
                          _buildOverviewSection(
                            localizations,
                            bookings.length,
                            0.0,
                          ),
                          const SizedBox(height: 24),
                          // Active Tickets Section
                          _buildActiveTicketsSection(localizations, bookings),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () {
                // Bookings still loading - show loading state
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading your tickets...',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
              error: (error, stack) {
                // Bookings error - show error with retry
                debugPrint('Error loading bookings: $error');
                debugPrint('Stack trace: $stack');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          localizations?.errorLoadingData ??
                              'Error loading data',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load data',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: () {
                            ref.invalidate(activeBookingsProvider);
                            ref.invalidate(walletBalanceProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Switch to Book tab (index 1) instead of navigating to a new page
          ref.read(navigationIndexProvider.notifier).state = 1;
          // Refresh data when switching to booking page
          ref.invalidate(activeBookingsProvider);
          ref.invalidate(walletBalanceProvider);
        },
        icon: const Icon(Icons.add),
        label: Text(localizations?.bookTicket ?? 'Book Ticket'),
      ),
    );
  }

  Widget _buildOverviewSection(
    AppLocalizations? localizations,
    int ticketCount,
    double walletBalance,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  localizations?.overview ?? 'Overview',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.account_balance_wallet_rounded,
                    label: localizations?.walletBalance ?? 'Wallet Balance',
                    value: '€${walletBalance.toStringAsFixed(2)}',
                    color: Colors.white,
                    isGradient: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _OverviewItem(
                    icon: Icons.confirmation_number_rounded,
                    label: localizations?.activeTickets ?? 'Active Tickets',
                    value: '$ticketCount',
                    color: Colors.white,
                    isGradient: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTicketsSection(
    AppLocalizations? localizations,
    List<models.Booking> bookings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.confirmation_number_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  localizations?.activeTickets ?? 'Active Tickets',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            if (bookings.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTicketsPage(),
                    ),
                  ).then((_) {
                    ref.invalidate(activeBookingsProvider);
                    ref.invalidate(walletBalanceProvider);
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(localizations?.viewAll ?? 'View All'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (bookings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.confirmation_number_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  localizations?.noActiveTickets ?? 'No active tickets',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  localizations?.bookFirstTicket ??
                      'Book your first ticket to get started',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(navigationIndexProvider.notifier).state = 1;
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(localizations?.bookTicket ?? 'Book Ticket'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...bookings
              .take(5)
              .map(
                (booking) => Padding(
                  key: ValueKey(booking.id),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BookingCard(
                    booking: booking,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TicketDetailsPage(booking: booking),
                        ),
                      );
                    },
                    onQRTap: booking.qrCode != null
                        ? () => _showQRCodePopup(context, booking)
                        : null,
                  ),
                ),
              ),
        if (bookings.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllTicketsPage(),
                    ),
                  ).then((_) {
                    ref.invalidate(activeBookingsProvider);
                    ref.invalidate(walletBalanceProvider);
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  '${localizations?.viewMore ?? 'View More'} (${bookings.length - 5} more)',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showQRCodePopup(BuildContext context, models.Booking booking) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'QR Code',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // QR Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: booking.qrCode!,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // Ticket Info
              Text(
                booking.ticketTypeName ?? 'Ticket',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (booking.validUntil != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Valid until: ${_formatDateTime(booking.validUntil!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Show this QR code to the validator when boarding',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isGradient;

  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGradient
            ? Colors.white.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: isGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGradient
                      ? Colors.white.withValues(alpha: 0.2)
                      : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isGradient ? Colors.white : color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isGradient
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isGradient ? Colors.white : color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
