import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../constants.dart';

class MyTicketsScreen extends StatefulWidget {
  final VoidCallback? onBookNew;
  const MyTicketsScreen({super.key, this.onBookNew});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMyTickets();
  }

  Future<void> _fetchMyTickets() async {
    if (_user?.email == null) return;
    if (mounted) setState(() { _isLoading = true; _error = null; });

    try {
      final url = Uri.parse(
        '${AppConfig.ticketsUrl}?student_id=${Uri.encodeComponent(_user!.email!)}&history=false',
      );
      final response = await http.get(url).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _tickets = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _error = "Could not load tickets"; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = "Network error"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Tickets", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMyTickets),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF52B788)))
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _fetchMyTickets, child: const Text("Retry")),
                  ],
                ))
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text("No active tickets for today", style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 16),
                          if (widget.onBookNew != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF52B788),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text("Book a Ticket", style: TextStyle(color: Colors.white)),
                              onPressed: () {
                                widget.onBookNew!();
                                _fetchMyTickets();
                              },
                            ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchMyTickets,
                      color: const Color(0xFF52B788),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (ctx, i) => _ActiveTicketCard(ticket: _tickets[i]),
                      ),
                    ),
    );
  }
}

class _ActiveTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _ActiveTicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final routeDetails = ticket['route_details'];
    final busDetails = ticket['bus_details'];
    final bookingId = ticket['booking_id'] ?? "";
    final hasBus = busDetails != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Top section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      routeDetails?['name'] ?? "Route",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ticket['status'] ?? "Active",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (routeDetails != null)
                  Text(
                    "${routeDetails['boarding_point']} → ${routeDetails['dropping_point']}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          // Middle — dashed separator
          const DashedDivider(),
          // QR section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // QR Code
                QrImageView(
                  data: bookingId,
                  size: 100,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TicketInfo("Booking ID", bookingId),
                      const SizedBox(height: 8),
                      _TicketInfo("Travel Date", ticket['travel_date'] ?? "Today"),
                      const SizedBox(height: 8),
                      if (hasBus) ...[
                        _TicketInfo("Bus Code", busDetails!['bus_id_code'] ?? "—", highlight: true),
                        const SizedBox(height: 4),
                        const Text("🚌 Bus Assigned!", style: TextStyle(color: Color(0xFF52B788), fontWeight: FontWeight.bold, fontSize: 12)),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "⏳ Awaiting Bus Assignment",
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _TicketInfo(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: highlight ? const Color(0xFF2D6A4F) : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(30, (i) => Expanded(
          child: Container(
            height: 1,
            color: i.isEven ? Colors.grey[300] : Colors.transparent,
          ),
        )),
      ),
    );
  }
}