import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/booking_service.dart';
import '../models/booking.dart';

class QRCodePage extends StatefulWidget {
  final Booking? initialBooking;

  const QRCodePage({super.key, this.initialBooking});

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  final BookingService _bookingService = BookingService();
  Booking? _selectedBooking;
  List<Booking> _activeBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialBooking != null) {
      // If a specific booking is provided, use it directly
      _selectedBooking = widget.initialBooking;
      _isLoading = false;
      // Still load all bookings for the dropdown if needed
      _loadBookings();
    } else {
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await _bookingService.getActiveBookings();
      setState(() {
        _activeBookings = bookings;
        // Filter bookings with QR codes
        final bookingsWithQR = bookings.where((b) => b.qrCode != null).toList();

        // If we have an initialBooking, find the matching booking by ID from the loaded list
        if (widget.initialBooking != null) {
          final matchingBooking =
              bookingsWithQR
                  .where((b) => b.id == widget.initialBooking!.id)
                  .isNotEmpty
              ? bookingsWithQR.firstWhere(
                  (b) => b.id == widget.initialBooking!.id,
                )
              : null;
          _selectedBooking =
              matchingBooking ??
              (bookingsWithQR.isNotEmpty ? bookingsWithQR.first : null);
        } else if (_selectedBooking == null) {
          // Find first booking with QR code
          _selectedBooking = bookingsWithQR.isNotEmpty
              ? bookingsWithQR.first
              : null;
        } else {
          // If _selectedBooking was set but not from initialBooking, find it in the list by ID
          final matchingBooking =
              bookingsWithQR
                  .where((b) => b.id == _selectedBooking!.id)
                  .isNotEmpty
              ? bookingsWithQR.firstWhere((b) => b.id == _selectedBooking!.id)
              : null;
          _selectedBooking =
              matchingBooking ??
              (bookingsWithQR.isNotEmpty ? bookingsWithQR.first : null);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading bookings: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedBooking == null || _selectedBooking!.qrCode == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active tickets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book a ticket to generate a QR code',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Ticket selector
                  Builder(
                    builder: (context) {
                      final bookingsWithQR = _activeBookings
                          .where((b) => b.qrCode != null)
                          .toList();
                      if (bookingsWithQR.length <= 1) {
                        return const SizedBox.shrink();
                      }

                      // Find the selected booking in the list by ID
                      final selectedBookingInList = _selectedBooking != null
                          ? bookingsWithQR
                                    .where((b) => b.id == _selectedBooking!.id)
                                    .isNotEmpty
                                ? bookingsWithQR.firstWhere(
                                    (b) => b.id == _selectedBooking!.id,
                                  )
                                : null
                          : null;

                      return Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Ticket',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<Booking>(
                                    key: ValueKey(
                                      'dropdown_${selectedBookingInList?.id ?? 'null'}',
                                    ),
                                    value: selectedBookingInList,
                                    items: bookingsWithQR.map((booking) {
                                      return DropdownMenuItem<Booking>(
                                        value: booking,
                                        child: Text(
                                          '${booking.ticketTypeName ?? "Ticket"} - €${booking.totalPrice.toStringAsFixed(2)}',
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (booking) {
                                      setState(() {
                                        _selectedBooking = booking;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  // QR Code
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _selectedBooking!.qrCode!,
                            version: QrVersions.auto,
                            size: 280.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _selectedBooking!.ticketTypeName ?? 'Ticket',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_selectedBooking!.validUntil != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Valid until: ${_formatDateTime(_selectedBooking!.validUntil!)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Instructions
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Show this QR code to the validator when boarding',
                              style: TextStyle(color: Colors.blue[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
