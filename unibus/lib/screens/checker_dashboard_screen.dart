import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'login_screen.dart';

class CheckerDashboardScreen extends StatefulWidget {
  final String checkerName;
  final String checkerEmail;
  const CheckerDashboardScreen({
    super.key,
    required this.checkerName,
    required this.checkerEmail,
  });

  @override
  State<CheckerDashboardScreen> createState() => _CheckerDashboardScreenState();
}

class _CheckerDashboardScreenState extends State<CheckerDashboardScreen> {
  final _busCodeController = TextEditingController();
  String _busCode = "";
  bool _isBusCodeSet = false;
  bool _isValidating = false;
  int _validatedCount = 0;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;

  @override
  void dispose() {
    _busCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _setBusCode() {
    final code = _busCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnack("Enter the exact 6-character Bus Code from the dispatch system.", Colors.orange);
      return;
    }
    setState(() {
      _busCode = code;
      _isBusCodeSet = true;
    });
  }

  Future<void> _validateTicket(String bookingId) async {
    if (_isValidating) return;
    setState(() => _isValidating = true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.validateTicketUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "bus_id_code": _busCode,
          "booking_id": bookingId,
        }),
      ).timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => _validatedCount++);
        _showResultDialog(
          success: true,
          title: "✅ Valid Ticket",
          lines: [
            "Passenger: ${data['student_name'] ?? 'Unknown'}",
            "ID: ${data['student_id'] ?? ''}",
            "Route: ${data['route'] ?? ''}",
          ],
        );
      } else {
        _showResultDialog(
          success: false,
          title: "❌ Invalid Ticket",
          lines: [data['error'] ?? "Verification failed"],
        );
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog(
          success: false,
          title: "Connection Error",
          lines: ["Could not reach server. Check internet connection."],
        );
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required List<String> lines,
  }) {
    _scannerController.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.cancel,
                color: success ? Colors.green : Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l, style: const TextStyle(fontSize: 15)),
          )).toList(),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? const Color(0xFF52B788) : Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _scannerController.start();
              setState(() => _isScanning = true);
            },
            child: const Text("Scan Next", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  Widget _buildBusCodeSetup() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_bus, size: 80, color: Color(0xFF52B788)),
          const SizedBox(height: 24),
          Text(
            "Welcome, ${widget.checkerName}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the 6-character Bus Code from the dispatch system to begin validation.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _busCodeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "ABC123",
              hintStyle: const TextStyle(letterSpacing: 8, color: Colors.grey),
              counterText: "",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D6A4F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _setBusCode,
              child: const Text("Start Checking", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF2D6A4F),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bus Code: $_busCode",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("Validated: $_validatedCount tickets",
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              TextButton(
                onPressed: () => setState(() {
                  _isBusCodeSet = false;
                  _busCode = "";
                  _busCodeController.clear();
                  _isScanning = false;
                  _scannerController.stop();
                }),
                child: const Text("Change Bus", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        // Scanner
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final barcode = capture.barcodes.firstOrNull;
                  if (barcode?.rawValue != null && !_isValidating) {
                    _validateTicket(barcode!.rawValue!);
                  }
                },
              ),
              // Overlay
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF52B788), width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_isValidating)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        // Scan button
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.grey : const Color(0xFF52B788),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (_isScanning) {
                  _scannerController.stop();
                  setState(() => _isScanning = false);
                } else {
                  _scannerController.start();
                  setState(() => _isScanning = true);
                }
              },
              icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner, color: Colors.white),
              label: Text(_isScanning ? "Stop Scanning" : "Start Scanning",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Ticket Checker", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            ),
            icon: const Icon(Icons.logout, color: Colors.red, size: 18),
            label: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: _isBusCodeSet ? _buildScanner() : _buildBusCodeSetup(),
    );
  }
}
