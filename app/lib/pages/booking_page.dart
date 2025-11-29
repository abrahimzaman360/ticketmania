import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:app/l10n/app_localizations.dart';
import '../services/booking_service.dart';
import '../services/wallet_service.dart';
import '../services/favorite_service.dart';
import '../services/widget_service.dart';
import '../services/ble_service.dart';
import '../models/ticket_type.dart';
import '../models/station.dart';
import '../models/favorite_ticket.dart';
import 'map_page.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final BookingService _bookingService = BookingService();
  final WalletService _walletService = WalletService();
  final FavoriteService _favoriteService = FavoriteService();
  final WidgetService _widgetService = WidgetService();

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

  String? _widgetFavoriteId;

  // Category definitions
  static const List<String> _categories = ['Individual', 'Family', 'Friends', 'Group'];
  static const int _maxFavorites = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkWidgetFavorite();
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
      final favorite = _favorites.firstWhere(
        (f) => f.id == _widgetFavoriteId,
      );
      
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
        _favorites = (results[2] as List<FavoriteTicket>).take(_maxFavorites).toList();
        if (_selectedTicketType == null && _ticketTypes.isNotEmpty) {
          _selectedTicketType = _ticketTypes.first;
        }
        _isLoading = false;
      });
      await _widgetService.updateWidget(_favorites);
      // Check favorite status after loading
      _checkFavoriteStatus();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_selectedTicketType == null || _isCheckingFavorite) return;
    
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

  Future<void> _bookFromFavorite(FavoriteTicket favorite, {bool fromWidget = false}) async {
    setState(() {
      _selectedTicketType = _ticketTypes.firstWhere(
        (t) => t.id == favorite.ticketTypeId,
        orElse: () => _ticketTypes.first,
      );
      _fromStation = favorite.fromStationId != null
          ? _stations.where((s) => s.id == favorite.fromStationId).isNotEmpty
              ? _stations.firstWhere((s) => s.id == favorite.fromStationId)
              : null
          : null;
      _toStation = favorite.toStationId != null
          ? _stations.where((s) => s.id == favorite.toStationId).isNotEmpty
              ? _stations.firstWhere((s) => s.id == favorite.toStationId)
              : null
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
            content: Text('Maximum $_maxFavorites favorites allowed. Please remove one first.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: $e')),
        );
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
            title: Text(localizations?.insufficientBalance ?? 'Insufficient Balance'),
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

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations?.ticketBookedSuccessfully ?? 'Ticket booked successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
        
        await _loadData();
        
        try {
          final bleService = Provider.of<BLEService>(context, listen: false);
          bleService.updateActiveTickets();
        } catch (e) {
          // BLE service might not be initialized
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations?.bookingFailed ?? 'Booking failed'}: $e')),
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
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Favorites Section with Count Badge
                    if (_favorites.isNotEmpty) ...[
                      Row(
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            final favorite = _favorites[index];
                            return Container(
                              width: 180,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  onTap: () => _bookFromFavorite(favorite),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                favorite.ticketTypeName ?? 'Ticket',
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
                                              onPressed: () async {
                                                await _favoriteService.removeFavorite(favorite.id);
                                                await _loadData();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Remove',
                                            ),
                                          ],
                                        ),
                                        if (favorite.ticketPrice != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '€${(favorite.ticketPrice! * favorite.quantity).toStringAsFixed(2)}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          localizations?.tapToFillForm ?? 'Tap to fill form',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
                              onTap: () => setState(() => _selectedCategory = category),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

                    // Compact Ticket Type Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations?.selectTicketType ?? 'Ticket Type',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedTicketType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '€${(_selectedTicketType!.price * _quantity).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonFormField<TicketType>(
                        value: _selectedTicketType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          hintText: localizations?.selectTicketType ?? 'Select Ticket Type',
                        ),
                        items: _filteredTicketTypes.map((type) {
                          return DropdownMenuItem<TicketType>(
                            value: type,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        type.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        '${type.formattedPrice} • ${type.durationText}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTicketType = value;
                            _isCurrentFavorite = null; // Reset favorite status
                          });
                          _checkFavoriteStatus();
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Station Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localizations?.selectStations ?? 'Stations',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
                              setState(() => _fromStation = station);
                            }
                          },
                          tooltip: 'Select from map',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Station>(
                      key: ValueKey('from_station_${_fromStation?.id ?? 'null'}_${_stations.length}'),
                      decoration: InputDecoration(
                        labelText: localizations?.fromStation ?? 'From Station',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      value: _fromStation != null && _stations.any((s) => s.id == _fromStation!.id)
                          ? _fromStation
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
                          _isCurrentFavorite = null; // Reset favorite status
                        });
                        _checkFavoriteStatus();
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Station>(
                      key: ValueKey('to_station_${_toStation?.id ?? 'null'}_${_stations.length}'),
                      decoration: InputDecoration(
                        labelText: localizations?.toStation ?? 'To Station',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                      value: _toStation != null && _stations.any((s) => s.id == _toStation!.id)
                          ? _toStation
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
                          _isCurrentFavorite = null; // Reset favorite status
                        });
                        _checkFavoriteStatus();
                      },
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
                                          _isCurrentFavorite = null; // Reset favorite status
                                        });
                                        _checkFavoriteStatus();
                                      }
                                    : null,
                                icon: const Icon(Icons.remove),
                                iconSize: 20,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    _isCurrentFavorite = null; // Reset favorite status
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
                            theme.colorScheme.primaryContainer.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
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
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          // Favorite Icon Button (Icon Only) - Using cached status
                          Builder(
                            builder: (context) {
                              final isFavorite = _isCurrentFavorite ?? false;
                              final canAddFavorite = _favorites.length < _maxFavorites;
                              return IconButton(
                                onPressed: _isBooking || !canAddFavorite || _isCheckingFavorite
                                    ? null
                                    : _addToFavorites,
                                icon: _isCheckingFavorite
                                    ? SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            theme.colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: isFavorite
                                            ? Colors.red
                                            : (canAddFavorite
                                                ? theme.colorScheme.onPrimaryContainer
                                                : Colors.grey),
                                        size: 28,
                                      ),
                                tooltip: _isCheckingFavorite
                                    ? 'Checking...'
                                    : isFavorite
                                        ? 'Remove from favorites'
                                        : canAddFavorite
                                            ? 'Add to favorites'
                                            : 'Maximum favorites reached',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Book Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isBooking || _selectedTicketType == null ? null : _bookTicket,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: _isBooking
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                localizations?.bookTicket ?? 'Book Ticket',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
