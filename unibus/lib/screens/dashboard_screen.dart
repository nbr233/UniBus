import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  String? _studentId;
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _balanceSubscription;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    if (user?.email == null) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.profilesUrl}${Uri.encodeComponent(user!.email!)}/'),
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _firstName = data['first_name'] ?? "Student";
            _walletBalance = double.tryParse(data['wallet_balance'].toString())?.toStringAsFixed(2) ?? "0.00";
            _studentId = data['student_id'];
            _isLoading = false;
          });
          if (_studentId != null) _listenToBalance(_studentId!);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listenToBalance(String studentId) {
    print("DEBUG: Starting Firebase listener for StudentID: $studentId");
    print("DEBUG: Full URL: ${AppConfig.firebaseDbUrl}/wallets/$studentId.json");
    _balanceSubscription?.cancel();
    
    try {
      _balanceSubscription = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: AppConfig.firebaseDbUrl)
          .ref('wallets/$studentId')
          .onValue
          .listen((event) {
        print("DEBUG: Firebase Snapshot Value: ${event.snapshot.value}");
        if (event.snapshot.value != null && mounted) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          if (data.containsKey('balance')) {
            final balance = double.tryParse(data['balance'].toString()) ?? 0.0;
            print("DEBUG: New Balance synced: $balance");
            setState(() => _walletBalance = balance.toStringAsFixed(2));
          }
        } else {
          print("DEBUG: Snapshot is null for path wallets/$studentId");
        }
      }, onError: (error) {
        print("DEBUG: Firebase Listener Error: $error");
      });
    } catch (e) {
      print("DEBUG: Firebase Initialization Error: $e");
    }
  }

  Future<void> _sendSOS() async {
    if (user?.email == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending SOS Alert..."), backgroundColor: Colors.orange),
    );
    try {
      final response = await http.post(
        Uri.parse(AppConfig.sosUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": user!.email, "message": "Emergency SOS from UniBus app"}),
      ).timeout(AppConfig.requestTimeout);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.statusCode == 201 ? "🚨 SOS Alert Sent!" : "Failed to send SOS"),
          backgroundColor: response.statusCode == 201 ? Colors.red : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Header (Exactly matching screenshot proportions) ──
          Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.35, // 35% of screen height
            decoration: const BoxDecoration(
              color: Color(0xFF69AD8E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20), // Spacer for status bar
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.directions_bus, 
                    size: 80, 
                    color: Colors.white
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "UNIBUS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),

          // ── Welcome & Wallet Info ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome back,",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Text(
                          _isLoading ? "Student" : _firstName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            studentId: _studentId,
                            walletBalance: _walletBalance,
                          ),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF69AD8E).withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: Color(0xFF69AD8E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // ── Wallet Balance Card ──
                GestureDetector(
                  onTap: () {
                    setState(() => _isLoading = true);
                    _fetchProfile();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF69AD8E).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF69AD8E), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Balance:",
                              style: TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                          ],
                        ),
                        _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF69AD8E)),
                              )
                            : Text(
                                "৳ $_walletBalance",
                                style: const TextStyle(
                                  fontSize: 20,
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
          const SizedBox(height: 20),

          // ── Menu Grid (original style) ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuItem(context, Icons.confirmation_number_outlined, "Book Ticket", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketOptionScreen()))
                        .then((_) => _fetchProfile());
                  }),
                  _buildMenuItem(context, Icons.access_time, "Schedule", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen()));
                  }),
                  _buildMenuItem(context, Icons.history_rounded, "History", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                  }),
                  _buildMenuItem(context, Icons.notifications_none, "Notice", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen()));
                  }),
                  _buildMenuItem(context, Icons.sensors_outlined, "SOS", isSOS: true, onTap: _sendSOS),
                  _buildMenuItem(context, Icons.location_on_outlined, "Live Tracking", onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("📍 Live Tracking Soon!"),
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

  Widget _buildMenuItem(BuildContext context, IconData icon, String title,
      {bool isSOS = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
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
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookTicketScreen()))
                  .then((_) => _fetchProfile());
            },
          ),
          IconButton(
            icon: const Icon(Icons.confirmation_number_outlined, color: Colors.black54),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTicketsScreen()));
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(
                  studentId: _studentId,
                  walletBalance: _walletBalance,
                )),
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