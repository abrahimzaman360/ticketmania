import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/l10n/app_localizations.dart';
import '../services/booking_service.dart';
import '../services/wallet_service.dart';
import '../services/favorite_service.dart';
import '../services/widget_service.dart';
import '../services/ble_service.dart';
import '../services/notification_service.dart';
import '../models/ticket_type.dart';
import '../models/station.dart';
import '../models/favorite_ticket.dart';
import '../providers/booking_providers.dart';
import '../providers/service_providers.dart';
import '../utils/error_handler.dart';
import 'map_page.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  final BookingService _bookingService = BookingService();
  final WalletService _walletService = WalletService();
  final FavoriteService _favoriteService = FavoriteService();
  final WidgetService _widgetService = WidgetService();
  final NotificationService _notificationService = NotificationService();

  List<TicketType> _ticketTypes = [];
  List<Station> _stations = [];
  List<FavoriteTicket> _favorites = [];
  TicketType? _selectedTicketType;
  Station? _fromStation;
  Station? _toStation;
  int _quantity = 1;
  bool _isLoading = true;
  bool _isBooking = false;
  String _selectedCategory = 'Individual'; // Default category
  bool? _isCurrentFavorite; // Cache favorite status
  bool _isCheckingFavorite = false;
  bool _isFavoritesExpanded = true; // Controls favorites section collapse

  String? _widgetFavoriteId;

  // Category definitions
  static const List<String> _categories = [
    'Individual',
    'Family',
    'Friends',
    'Group',
  ];
  static const int _maxFavorites = 5;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
    _checkWidgetFavorite();
  }

  Future<void> _initializeServices() async {
    try {
      await _notificationService.initialize();
      debugPrint(
        'Notification service initialized: ${_notificationService.isInitialized}',
      );
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  Future<void> _checkWidgetFavorite() async {
    try {
      final selectedFavorite = await _widgetService.getSelectedFavorite();
      if (selectedFavorite != null && selectedFavorite.isNotEmpty) {
        _widgetFavoriteId = selectedFavorite;
        await _loadData();
        if (mounted) {
          _handleWidgetFavorite();
        }
      }
    } catch (e) {
      debugPrint('Error checking widget favorite: $e');
    }
  }

  void _handleWidgetFavorite() {
    if (_widgetFavoriteId == null || _favorites.isEmpty) return;

    try {
      final favorite = _favorites.firstWhere((f) => f.id == _widgetFavoriteId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _bookFromFavorite(favorite, fromWidget: true);
        }
      });
    } catch (e) {
      debugPrint('Favorite not found: $e');
    } finally {
      _widgetFavoriteId = null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _bookingService.getTicketTypes(),
        _bookingService.getStations(),
        _favoriteService.getFavorites(),
      ]);
      setState(() {
        _ticketTypes = results[0] as List<TicketType>;
        _stations = results[1] as List<Station>;
        _favorites = (results[2] as List<FavoriteTicket>)
            .take(_maxFavorites)
            .toList();
        if (_selectedTicketType == null && _ticketTypes.isNotEmpty) {
          _selectedTicketType = _ticketTypes.first;
        } else if (_selectedTicketType != null && _ticketTypes.isNotEmpty) {
          // Ensure the selected ticket type exists in the new list
          final matchingType = _ticketTypes.firstWhere(
            (t) => t.id == _selectedTicketType!.id,
            orElse: () => _ticketTypes.first,
          );
          _selectedTicketType = matchingType;
        }
        // Ensure selected stations exist in the new list
        if (_fromStation != null && _stations.isNotEmpty) {
          final matchingFromStation = _stations.firstWhere(
            (s) => s.id == _fromStation!.id,
            orElse: () => _stations.first,
          );
          _fromStation = matchingFromStation;
        }
        if (_toStation != null && _stations.isNotEmpty) {
          final matchingToStation = _stations.firstWhere(
            (s) => s.id == _toStation!.id,
            orElse: () => _stations.first,
          );
          _toStation = matchingToStation;
        }
        _isLoading = false;
      });
      await _widgetService.updateWidget(_favorites);
      // Check favorite status after loading - only if we have a selected ticket type
      if (mounted && _selectedTicketType != null) {
        _checkFavoriteStatus();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showError(context, e, contextMessage: 'load data');
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_selectedTicketType == null || _isCheckingFavorite || !mounted) return;

    setState(() => _isCheckingFavorite = true);
    try {
      final isFavorite = await _favoriteService.isFavorite(
        ticketTypeId: _selectedTicketType!.id,
        fromStationId: _fromStation?.id,
        toStationId: _toStation?.id,
        quantity: _quantity,
      );
      if (mounted) {
        setState(() {
          _isCurrentFavorite = isFavorite;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      if (mounted) {
        setState(() {
          _isCurrentFavorite = false;
          _isCheckingFavorite = false;
        });
      }
    }
  }

  List<TicketType> get _filteredTicketTypes {
    // Filter by category - for now, show all types but can be enhanced
    return _ticketTypes;
  }

  Future<void> _bookFromFavorite(
    FavoriteTicket favorite, {
    bool fromWidget = false,
  }) async {
    setState(() {
      _selectedTicketType = _ticketTypes.firstWhere(
        (t) => t.id == favorite.ticketTypeId,
        orElse: () => _ticketTypes.first,
      );
      _fromStation = favorite.fromStationId != null && _stations.isNotEmpty
          ? _stations.firstWhere(
              (s) => s.id == favorite.fromStationId,
              orElse: () => _stations.first,
            )
          : null;
      _toStation = favorite.toStationId != null && _stations.isNotEmpty
          ? _stations.firstWhere(
              (s) => s.id == favorite.toStationId,
              orElse: () => _stations.first,
            )
          : null;
      _quantity = favorite.quantity;
    });

    if (fromWidget) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localizations?.bookTicket ?? 'Book Ticket'),
          content: Text(
            'Book ${favorite.ticketTypeName ?? "ticket"} for €${(favorite.ticketPrice ?? 0) * favorite.quantity}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(localizations?.book ?? 'Book'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        await _bookTicket();
      }
    }
  }

  Future<void> _addToFavorites() async {
    if (_selectedTicketType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a ticket type')),
      );
      return;
    }

    // Check if max favorites reached
    if (_favorites.length >= _maxFavorites) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum $_maxFavorites favorites allowed. Please remove one first.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final favoriteId = await _favoriteService.getFavoriteId(
        ticketTypeId: _selectedTicketType!.id,
        fromStationId: _fromStation?.id,
        toStationId: _toStation?.id,
        quantity: _quantity,
      );

      if (favoriteId != null) {
        await _favoriteService.removeFavorite(favoriteId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from favorites'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await _favoriteService.addFavorite(
          ticketTypeId: _selectedTicketType!.id,
          fromStationId: _fromStation?.id,
          toStationId: _toStation?.id,
          quantity: _quantity,
        );
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations?.favorited ?? 'Added to favorites'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }

      await _loadData();
      await _widgetService.updateWidget(_favorites);
      // Refresh favorite status after adding/removing
      _checkFavoriteStatus();
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e, contextMessage: 'update favorite');
      }
    }
  }

  Future<void> _bookTicket() async {
    if (_selectedTicketType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a ticket type')),
      );
      return;
    }

    setState(() => _isBooking = true);
    try {
      final wallet = await _walletService.getWallet();
      final totalPrice = _selectedTicketType!.price * _quantity;

      if (wallet.balance < totalPrice) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              localizations?.insufficientBalance ?? 'Insufficient Balance',
            ),
            content: Text(
              'Your balance is €${wallet.balance.toStringAsFixed(2)}, but you need €${totalPrice.toStringAsFixed(2)}. Would you like to add money?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(localizations?.cancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(localizations?.addMoney ?? 'Add Money'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        if (result == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please go to Wallet tab to add money'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() => _isBooking = false);
          return;
        }
        setState(() => _isBooking = false);
        return;
      }

      final booking = await _bookingService.createBooking(
        ticketTypeId: _selectedTicketType!.id,
        fromStationId: _fromStation?.id,
        toStationId: _toStation?.id,
        quantity: _quantity,
      );

      await _walletService.deductMoney(
        totalPrice,
        bookingId: booking.id,
        description: 'Ticket booking: ${_selectedTicketType!.name}',
      );

      await _bookingService.confirmBooking(booking.id);

      // Show notification for successful booking
      try {
        // Ensure notification service is initialized
        if (!_notificationService.isInitialized) {
          await _notificationService.initialize();
        }
        await _notificationService.showBookingSuccessNotification(
          ticketTypeName: _selectedTicketType!.name,
          price: _selectedTicketType!.price,
          quantity: _quantity,
          bookingId: booking.id,
        );
      } catch (e) {
        debugPrint('Error showing booking notification: $e');
        // Don't fail the booking if notification fails
      }

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations?.ticketBookedSuccessfully ??
                  'Ticket booked successfully!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );

        // Invalidate booking providers to refresh ticket lists
        ref.invalidate(activeBookingsProvider);
        ref.invalidate(allBookingsProvider);
        // Invalidate wallet balance provider to refresh balance
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(walletProvider);

        await _loadData();

        if (mounted) {
          try {
            final bleService = provider.Provider.of<BLEService>(context, listen: false);
            bleService.updateActiveTickets();
          } catch (e) {
            // BLE service might not be initialized
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations?.bookingFailed ?? 'Booking failed'}: $e',
            ),
          ),
        );
      }
    } finally {
      setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          localizations?.bookTicket ?? 'Book Ticket',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ticketTypes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.errorLoadingData ?? 'Error loading data',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Favorites Section with Count Badge - Collapsible
                    if (_favorites.isNotEmpty) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isFavoritesExpanded = !_isFavoritesExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    localizations?.favorites ?? 'Favorites',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_favorites.length}/$_maxFavorites',
                                      style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              AnimatedRotation(
                                turns: _isFavoritesExpanded ? 0 : -0.25,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: Column(
                          children: [
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites[index];
                            // Find matching ticket type for additional info
                            TicketType? ticketType;
                            try {
                              ticketType = _ticketTypes.firstWhere(
                                (t) => t.id == favorite.ticketTypeId,
                              );
                            } catch (e) {
                              ticketType = null;
                            }
                            return Container(
                              width: 220,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  onTap: () => _bookFromFavorite(favorite),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          theme.colorScheme.primaryContainer,
                                          theme.colorScheme.primaryContainer
                                              .withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Header with title and favorite icon
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  favorite.ticketTypeName ??
                                                      'Ticket',
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              InkWell(
                                                onTap: () async {
                                                  await _favoriteService
                                                      .removeFavorite(
                                                        favorite.id,
                                                      );
                                                  await _loadData();
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    4.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.favorite,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Duration/Validity info
                                          if (ticketType != null)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 11,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    ticketType.durationText,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.grey[600],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 6),
                                          // Station information
                                          if (favorite.fromStationName !=
                                                  null ||
                                              favorite.toStationName != null)
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (favorite.fromStationName !=
                                                    null)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        size: 11,
                                                        color: Colors.grey[700],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          favorite.fromStationName ??
                                                              '',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (favorite.fromStationName !=
                                                        null &&
                                                    favorite.toStationName !=
                                                        null)
                                                  const SizedBox(height: 2),
                                                if (favorite.toStationName !=
                                                    null)
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 11,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          favorite.toStationName ??
                                                              '',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          const Spacer(),
                                          const SizedBox(height: 6),
                                          // Price and quantity
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (favorite.ticketPrice != null)
                                                Expanded(
                                                  child: Text(
                                                    '€${(favorite.ticketPrice! * favorite.quantity).toStringAsFixed(2)}',
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (favorite.quantity > 1)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'x${favorite.quantity}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                              },
                            ),
                          ),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                        crossFadeState: _isFavoritesExpanded
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 200),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Category Selection - New Design
                    Text(
                      'Category',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  category,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Inline Ticket Type Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations?.selectTicketType ?? 'Ticket Type',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedTicketType != null)
                          InkWell(
                            onTap: () {
                              // Show bottom sheet to select ticket type
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) => Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations?.selectTicketType ??
                                            'Select Ticket Type',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      ..._filteredTicketTypes.map((type) {
                                        final isSelected =
                                            _selectedTicketType?.id == type.id;
                                        return ListTile(
                                          selected: isSelected,
                                          leading: Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : Colors.grey,
                                          ),
                                          title: Text(
                                            type.name,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${type.formattedPrice} • ${type.durationText}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              _selectedTicketType = type;
                                              _isCurrentFavorite = null;
                                            });
                                            _checkFavoriteStatus();
                                            Navigator.pop(context);
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedTicketType!.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.euro,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedTicketType!
                                                  .formattedPrice,
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.access_time,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedTicketType!.durationText,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    localizations?.selectTicketType ??
                                        'Select Ticket Type',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Station Selection - Fixed layout
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                localizations?.selectStations ?? 'Stations',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.map_outlined),
                              onPressed: () async {
                                final station = await Navigator.push<Station>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MapPage(),
                                  ),
                                );
                                if (mounted && station != null) {
                                  // Find the matching station from the list to ensure reference equality
                                  final matchingStation = _stations.isNotEmpty
                                      ? _stations.firstWhere(
                                          (s) => s.id == station.id,
                                          orElse: () => station,
                                        )
                                      : station;
                                  setState(
                                    () => _fromStation = matchingStation,
                                  );
                                }
                              },
                              tooltip: 'Select from map',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Station>(
                          key: ValueKey(
                            'from_station_${_fromStation?.id ?? 'null'}_${_stations.length}',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                localizations?.fromStation ?? 'From Station',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          initialValue:
                              _fromStation != null && _stations.isNotEmpty
                              ? _stations
                                        .where((s) => s.id == _fromStation!.id)
                                        .isNotEmpty
                                    ? _stations.firstWhere(
                                        (s) => s.id == _fromStation!.id,
                                      )
                                    : null
                              : null,
                          items: [
                            DropdownMenuItem<Station>(
                              value: null,
                              child: Text(localizations?.any ?? 'Any'),
                            ),
                            ..._stations.map(
                              (station) => DropdownMenuItem<Station>(
                                value: station,
                                child: Text(station.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _fromStation = value;
                              _isCurrentFavorite =
                                  null; // Reset favorite status
                            });
                            _checkFavoriteStatus();
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Station>(
                          key: ValueKey(
                            'to_station_${_toStation?.id ?? 'null'}_${_stations.length}',
                          ),
                          decoration: InputDecoration(
                            labelText: localizations?.toStation ?? 'To Station',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          initialValue:
                              _toStation != null && _stations.isNotEmpty
                              ? _stations
                                        .where((s) => s.id == _toStation!.id)
                                        .isNotEmpty
                                    ? _stations.firstWhere(
                                        (s) => s.id == _toStation!.id,
                                      )
                                    : null
                              : null,
                          items: [
                            DropdownMenuItem<Station>(
                              value: null,
                              child: Text(localizations?.any ?? 'Any'),
                            ),
                            ..._stations.map(
                              (station) => DropdownMenuItem<Station>(
                                value: station,
                                child: Text(station.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _toStation = value;
                              _isCurrentFavorite =
                                  null; // Reset favorite status
                            });
                            _checkFavoriteStatus();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quantity Selector - Modern Design
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations?.quantity ?? 'Quantity',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () {
                                        setState(() {
                                          _quantity--;
                                          _isCurrentFavorite =
                                              null; // Reset favorite status
                                        });
                                        _checkFavoriteStatus();
                                      }
                                    : null,
                                icon: const Icon(Icons.remove),
                                iconSize: 20,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  '$_quantity',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _quantity++;
                                    _isCurrentFavorite =
                                        null; // Reset favorite status
                                  });
                                  _checkFavoriteStatus();
                                },
                                icon: const Icon(Icons.add),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Total Price Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.7,
                            ),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations?.total ?? 'Total',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '€${(_selectedTicketType?.price ?? 0) * _quantity}',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Favorite Button - Always visible at the end
                          Builder(
                            builder: (context) {
                              final isFavorite = _isCurrentFavorite ?? false;
                              final canAddFavorite =
                                  _favorites.length < _maxFavorites;
                              return PopupMenuButton<String>(
                                icon: _isCheckingFavorite
                                    ? SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                theme
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                        isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFavorite
                                            ? Colors.red
                                            : (canAddFavorite
                                                  ? theme
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                  : Colors.grey),
                                        size: 28,
                                      ),
                                onSelected: (value) {
                                  if (value == 'toggle' && !_isBooking) {
                                    _addToFavorites();
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem<String>(
                                    value: 'toggle',
                                    enabled:
                                        !_isBooking &&
                                        !_isCheckingFavorite &&
                                        canAddFavorite &&
                                        _selectedTicketType != null,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isFavorite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isFavorite
                                              ? Colors.red
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          isFavorite
                                              ? 'Remove from favorites'
                                              : 'Add to favorites',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Book Button - More Focused and Prominent
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isBooking || _selectedTicketType == null
                            ? null
                            : _bookTicket,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        child: _isBooking
                            ? const SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.confirmation_number,
                                    size: 24,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    localizations?.bookTicket ?? 'Book Ticket',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
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
