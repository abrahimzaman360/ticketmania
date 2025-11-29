import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/booking_service.dart';
import '../widgets/booking_card.dart';
import 'ticket_details_page.dart';
import 'qr_code_page.dart';

class AllTicketsPage extends StatefulWidget {
  const AllTicketsPage({super.key});

  @override
  State<AllTicketsPage> createState() => _AllTicketsPageState();
}

class _AllTicketsPageState extends State<AllTicketsPage> {
  final BookingService _bookingService = BookingService();
  List<Booking> _allBookings = [];
  List<Booking> _displayedBookings = [];
  String _selectedFilter = 'all';
  bool _isLoading = true;
  bool _showAll = false;

  final List<Map<String, String>> _filters = [
    {'value': 'all', 'label': 'All'},
    {'value': 'family', 'label': 'Family'},
    {'value': 'used', 'label': 'Used'},
    {'value': 'expired', 'label': 'Expired'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _showAll = false;
    });

    try {
      final bookings = await _bookingService.getAllBookings(
        filter: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _displayedBookings = bookings.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tickets: $e')),
        );
      }
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _showAll = false;
    });
    _loadBookings();
  }

  void _toggleShowAll() {
    setState(() {
      _showAll = !_showAll;
      _displayedBookings = _showAll
          ? _allBookings
          : _allBookings.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _onFilterChanged(filter['value']!);
                        }
                      },
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Tickets List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allBookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tickets found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting a different filter',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBookings,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _displayedBookings.length + (_allBookings.length > 5 ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _displayedBookings.length) {
                              // Show "View More" or "Show Less" button
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _toggleShowAll,
                                    icon: Icon(
                                      _showAll ? Icons.expand_less : Icons.expand_more,
                                    ),
                                    label: Text(
                                      _showAll
                                          ? 'Show Less'
                                          : 'View More (${_allBookings.length - 5} more)',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final booking = _displayedBookings[index];
                            return Padding(
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
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

