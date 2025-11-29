import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../main.dart';
import '../services/booking_service.dart';

class ValidateTicketPage extends StatefulWidget {
  const ValidateTicketPage({super.key});

  @override
  State<ValidateTicketPage> createState() => _ValidateTicketPageState();
}

class _ValidateTicketPageState extends State<ValidateTicketPage>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  final BookingService _bookingService = BookingService();
  bool _isValidating = false;
  bool _hasScanned = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't initialize camera here - wait until page is visible
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _startCamera();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopCamera();
    }
  }

  void _initializeCamera() {
    if (!_isInitialized) {
      _controller = MobileScannerController();
      _isInitialized = true;
      _startCamera();
    }
  }

  void _startCamera() {
    if (_controller != null) {
      try {
        _controller!.start();
      } catch (e) {
        // Camera might already be running, ignore
      }
    }
  }

  void _stopCamera() {
    if (_controller != null) {
      try {
        _controller!.stop();
      } catch (e) {
        // Camera might not be running, ignore
      }
    }
  }

  Future<void> _validateQRCode(String qrCode) async {
    if (_isValidating || _hasScanned) return;

    setState(() {
      _isValidating = true;
      _hasScanned = true;
    });

    // Stop scanning while validating
    await _controller?.stop();

    try {
      // Find booking by QR code
      final response = await supabase
          .from('bookings')
          .select()
          .eq('qr_code', qrCode)
          .single();

      final bookingId = response['id'] as String;

      // Validate the ticket
      await _bookingService.validateTicket(
        bookingId,
        validationType: 'qr',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket validated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset for next scan
        setState(() {
          _hasScanned = false;
          _isValidating = false;
        });
        _startCamera();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Resume scanning on error
        setState(() {
          _hasScanned = false;
          _isValidating = false;
        });
        _startCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize camera only when widget is built (page is visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isInitialized) {
        _initializeCamera();
      }
    });

    // If camera not initialized, show placeholder
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller!,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null && !_hasScanned) {
                  _validateQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Scanner overlay
          CustomPaint(
            painter: _ScannerOverlay(),
            child: Container(),
          ),
          if (_isValidating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Validating ticket...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final cutOutSize = 250.0;
    final left = (size.width - cutOutSize) / 2;
    final top = (size.height - cutOutSize) / 2;
    final right = left + cutOutSize;
    final bottom = top + cutOutSize;

    // Draw overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(10),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final borderPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          const Radius.circular(10),
        ),
      );

    canvas.drawPath(borderPath, borderPaint);

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final cornerLength = 30.0;
    // Top-left
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
