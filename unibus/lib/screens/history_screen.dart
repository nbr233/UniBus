import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (_user?.email == null) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final url = Uri.parse(
        '${AppConfig.ticketsUrl}?student_id=${Uri.encodeComponent(_user!.email!)}&history=true',
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
        if (mounted) setState(() { _isLoading = false; _error = "Failed to load history"; });
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
        title: const Text("Ticket History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchHistory),
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
                    ElevatedButton(onPressed: _fetchHistory, child: const Text("Retry")),
                  ],
                ))
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text("No ticket history", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      color: const Color(0xFF52B788),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tickets.length,
                        itemBuilder: (ctx, i) => _TicketHistoryCard(ticket: _tickets[i]),
                      ),
                    ),
    );
  }
}

class _TicketHistoryCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketHistoryCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final routeDetails = ticket['route_details'];
    final busDetails = ticket['bus_details'];
    final isUsed = ticket['status'] == 'Used';
    final isActive = ticket['status'] == 'Active';

    final statusColor = isUsed
        ? Colors.green
        : isActive
            ? const Color(0xFF52B788)
            : Colors.grey;

    final bookedAt = ticket['booked_at'] != null
        ? DateTime.tryParse(ticket['booked_at'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    routeDetails?['name'] ?? "Unknown Route",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ticket['status'] ?? "—",
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (routeDetails != null)
              Text(
                "${routeDetails['boarding_point']} → ${routeDetails['dropping_point']}",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    icon: Icons.confirmation_number_outlined,
                    label: "Booking ID",
                    value: ticket['booking_id'] ?? "—",
                  ),
                ),
                if (busDetails != null)
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.directions_bus_outlined,
                      label: "Bus: ${busDetails['vehicle_details']?['name'] ?? 'Bus'}",
                      value: busDetails['bus_id_code'] ?? "—",
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    icon: Icons.calendar_today_outlined,
                    label: "Travel Date",
                    value: ticket['travel_date'] ?? "—",
                  ),
                ),
                if (bookedAt != null)
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.access_time_outlined,
                      label: "Booked At",
                      value: "${bookedAt.hour.toString().padLeft(2, '0')}:${bookedAt.minute.toString().padLeft(2, '0')}",
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}