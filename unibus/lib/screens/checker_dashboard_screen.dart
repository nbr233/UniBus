import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';
import 'login_screen.dart';

class CheckerDashboardScreen extends StatefulWidget {
  const CheckerDashboardScreen({super.key});

  @override
  State<CheckerDashboardScreen> createState() => _CheckerDashboardScreenState();
}

class _CheckerDashboardScreenState extends State<CheckerDashboardScreen> {
  final _busIdController = TextEditingController();
  bool _isBusIdValid = false;
  String _busId = "";
  bool _isScanning = false;
  bool _isProcessing = false;

  void _validateBusId() {
    String input = _busIdController.text.trim();
    if (input.length == 6) {
      setState(() {
        _busId = input;
        _isBusIdValid = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bus ID must be exactly 6 characters"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _processQRCode(String bookingId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse(AppConfig.validateTicketUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "bus_id_code": _busId,
          "booking_id": bookingId,
        }),
      ).timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showResultDialog(
          title: "Valid Ticket",
          message: "Student: ${data['student_name']}\nID: ${data['student_id']}",
          isSuccess: true,
        );
      } else {
        final data = jsonDecode(response.body);
        _showResultDialog(
          title: "Invalid Ticket",
          message: data['error'] ?? "Unknown error",
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showResultDialog(
        title: "Connection Error",
        message: "Failed to verify ticket. Check internet connection.",
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showResultDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.cancel,
                color: isSuccess ? Colors.green : Colors.red,
                size: 30,
              ),
              const SizedBox(width: 10),
              Text(title),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Resume scanning if needed, or delay
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {}); // Reset state to allow next scan
                  }
                });
              },
              child: const Text("OK", style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _busIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checker Dashboard"),
        backgroundColor: const Color(0xFF69AD8E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: !_isBusIdValid ? _buildBusIdEntry() : _buildScanner(),
    );
  }

  Widget _buildBusIdEntry() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus, size: 80, color: Color(0xFF69AD8E)),
            const SizedBox(height: 20),
            const Text(
              "Enter Bus ID to start scanning",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _busIdController,
              decoration: InputDecoration(
                labelText: "6-Digit Bus ID",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.pin),
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _validateBusId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF69AD8E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Proceed", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          width: double.infinity,
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Active Bus ID: $_busId",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isBusIdValid = false;
                    _busIdController.clear();
                  });
                },
                child: const Text("Change Bus", style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String code = barcodes.first.rawValue ?? "";
                    if (code.isNotEmpty && !_isProcessing) {
                      _processQRCode(code);
                    }
                  }
                },
              ),
              // Simple Scanner Overlay
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Scan Student Ticket QR Code",
                    style: TextStyle(color: Colors.white, fontSize: 18, backgroundColor: Colors.black54),
                  ),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
