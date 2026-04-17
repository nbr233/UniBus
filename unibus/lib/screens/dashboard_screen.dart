import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ticket_option_screen.dart';
import 'book_ticket_screen.dart';
import 'my_tickets_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'notice_screen.dart';
import 'schedule_screen.dart';
import '../constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _firstName = "Student";
  String _walletBalance = "0.00";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    if (user?.email == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.profilesUrl}${user!.email}/'),
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _firstName = data['first_name'] ?? "Student";
            _walletBalance = data['wallet_balance'] ?? "0.00";
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSOS() async {
    if (user?.email == null) return;
    
    // Show sending snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending SOS Alert..."), backgroundColor: Colors.orange),
    );

    try {
      final response = await http.post(
        Uri.parse(AppConfig.sosUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": user!.email, "message": "Emergency SOS from app"}),
      ).timeout(AppConfig.requestTimeout);

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SOS Alert Sent Successfully!"), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send SOS"), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Network error sending SOS"), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- Header Section ---
          Container(
            height: MediaQuery.of(context).size.height * 0.40,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF69AD8E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 250,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.directions_bus, size: 100, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _isLoading ? "Welcome..." : "Welcome, $_firstName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() => _isLoading = true);
                      _fetchProfile();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 50),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Credit Balance:",
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.refresh, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
                            ],
                          ),
                          _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                            "৳ $_walletBalance",
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF69AD8E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          // --- Menu Grid ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuItem(context, Icons.confirmation_number_outlined, "Book Ticket", onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TicketOptionScreen()), 
                    );
                  }),

                  _buildMenuItem(context, Icons.access_time, "Schedule", onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                    );
                  }),
                  
                  _buildMenuItem(context, Icons.history_rounded, "History", onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    );
                  }),
                  
                  _buildMenuItem(context, Icons.notifications_none, "Notice", onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NoticeScreen()),
                    );
                  }),
                  _buildMenuItem(context, Icons.sensors_outlined, "SOS", isSOS: true, onTap: _sendSOS),
                  _buildMenuItem(context, Icons.location_on_outlined, "Live Tracking", onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("📍 Live Tracking শীঘ্রই আসছে!"),
                        backgroundColor: Color(0xFF69AD8E),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }),
                ], 
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {bool isSOS = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => debugPrint("$title Clicked"),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isSOS ? Colors.red.withValues(alpha: 0.05) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: isSOS ? Colors.red : Colors.black87),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSOS ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
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
            icon: const Icon(Icons.home_rounded, color: Color(0xFF69AD8E)), 
            onPressed: () {}
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black54), 
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const BookTicketScreen())
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: Colors.black54), 
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const MyTicketsScreen())
              );
            }
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ProfileScreen())
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}