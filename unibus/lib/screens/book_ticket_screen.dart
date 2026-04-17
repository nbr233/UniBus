import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class BookTicketScreen extends StatefulWidget {
  const BookTicketScreen({super.key});

  @override
  State<BookTicketScreen> createState() => _BookTicketScreenState();
}

class _BookTicketScreenState extends State<BookTicketScreen> {
  bool _isLoading = true;
  List<dynamic> _routeList = [];

  final String _routesUrl = AppConfig.routesUrl;
  final String _ticketUrl = AppConfig.ticketsUrl;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    try {
      final response = await http.get(Uri.parse(_routesUrl))
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        setState(() {
          _routeList = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showError("Failed to load routes.");
      }
    } catch (e) {
      _showError("Connection error.");
    }
  }

  Future<void> _bookTicket(Map<String, dynamic> route) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userEmail = user.email!;

    try {
      final response = await http.post(
        Uri.parse(_ticketUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "route_id": route['id'],
        }),
      ).timeout(AppConfig.requestTimeout);

      if (mounted) {
        if (response.statusCode == 201) {
          _showSnackBar("Ticket booked successfully! You can board any bus on this route.", Colors.green);
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context, true);
          });
        } else {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          _showSnackBar(responseData['error'] ?? "Booking failed", Colors.redAccent);
        }
      }
    } catch (e) {
      _showSnackBar("Network error.", Colors.redAccent);
    }
  }

  void _confirmBooking(Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Booking"),
        content: Text(
          "Do you want to buy a ticket for ${route['name']}? \nFare: ৳${route['fare']}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF69AD8E),
            ),
            onPressed: () {
              Navigator.pop(context);
              _bookTicket(route);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String m) {
    setState(() => _isLoading = false);
    _showSnackBar(m, Colors.redAccent);
  }

  void _showSnackBar(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: c,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Select Route",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF69AD8E)),
            )
          : _routeList.isEmpty
              ? const Center(
                  child: Text(
                    "No routes available.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _routeList.length,
                  itemBuilder: (context, index) {
                    final route = _routeList[index];
                    return GestureDetector(
                      onTap: () => _confirmBooking(route),
                      child: _buildRouteCard(route),
                    );
                  },
                ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6F4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF69AD8E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route["name"],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "${route['boarding_point']} → ${route['dropping_point']}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                if (route['schedule_time'] != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF69AD8E)),
                      const SizedBox(width: 5),
                      Text(
                        "Schedule: ${route['schedule_time']}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Text(
            "৳${route["fare"]}",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF69AD8E),
            ),
          ),
        ],
      ),
    );
  }
}