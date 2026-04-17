import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  bool _isQRFullView = false;
  String? _selectedQRData;
  List<dynamic> _activeTickets = [];
  bool _isLoading = true;

  final String _ticketUrl = AppConfig.ticketsUrl;

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  Future<void> _fetchMyTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userEmail = user.email!;

    try {
      final response = await http.get(
        Uri.parse('$_ticketUrl?student_id=${Uri.encodeComponent(userEmail)}&history=false'),
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        setState(() {
          _activeTickets = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isQRFullView
            ? null
            : const Text(
                "Active Tickets",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF69AD8E)),
                ),
              )
            else if (_activeTickets.isEmpty && !_isQRFullView)
              const Expanded(
                child: Center(
                  child: Text(
                    "No active tickets found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else if (!_isQRFullView)
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF69AD8E),
                  onRefresh: _fetchMyTickets,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _activeTickets.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _buildTicketCard(_activeTickets[index]),
                      );
                    },
                  ),
                ),
              ),

            if (_isQRFullView)
              Expanded(child: _buildLargeQR(_selectedQRData ?? "")),

            if (!_isQRFullView) _buildBottomNav(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final route = ticket['route_details'] as Map<String, dynamic>? ?? {};
    final bus = ticket['bus_details'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF69AD8E),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route["name"] ?? "Route",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${route['boarding_point']} → ${route['dropping_point']}",
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bus != null ? (bus["formatted_time"] ?? "--") : (route["schedule_time"] ?? "Flexible"),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "BUS ASSIGNMENT",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    bus != null ? (bus["bus_number"] ?? "Assigned") : "Awaiting Assignment",
                    style: TextStyle(
                      fontSize: 14,
                      color: bus != null ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontStyle: bus != null ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Booking ID: ${ticket['booking_id']}",
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedQRData = ticket["booking_id"];
                    _isQRFullView = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: QrImageView(
                    data: ticket["booking_id"] ?? "INVALID",
                    version: QrVersions.auto,
                    size: 70.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeQR(String qrData) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF69AD8E),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF69AD8E),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black54, size: 30),
              onPressed: () => setState(() => _isQRFullView = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black54),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.confirmation_number_outlined,
              color: Color(0xFF69AD8E),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}