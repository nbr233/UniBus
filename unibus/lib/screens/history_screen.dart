import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _historyTickets = [];
  bool _isLoading = true;

  final String _ticketUrl = AppConfig.ticketsUrl;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String userEmail = user.email!;

    try {
      final response = await http.get(
        Uri.parse('$_ticketUrl?student_id=${Uri.encodeComponent(userEmail)}&history=true'),
      ).timeout(AppConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        setState(() {
          _historyTickets = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("History fetching error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Journey History", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF69AD8E)))
          : _historyTickets.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _historyTickets.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(_historyTickets[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          const Text("No past journeys found.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> ticket) {
    final route = ticket['route_details'] as Map<String, dynamic>? ?? {};
    final bus = ticket['bus_details'] as Map<String, dynamic>?;
    DateTime bookedDate = DateTime.parse(ticket['booked_at']);
    String formattedDate = "${bookedDate.day}/${bookedDate.month}/${bookedDate.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                route['name'] ?? "Route",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ticket['status'] ?? 'Used',
                  style: TextStyle(
                    fontSize: 10, 
                    color: Colors.grey.shade600, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("POINTS", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text("${route['boarding_point']} → ${route['dropping_point']}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("DATE", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(formattedDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Bus: ${bus != null ? (bus['bus_number'] ?? 'N/A') : 'N/A'}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
              Text("ID: ${ticket['booking_id']}", style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic)),
            ],
          ),
        ],
      ),
    );
  }
}