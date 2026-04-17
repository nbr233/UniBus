import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'ticket_option_screen.dart';
import 'book_ticket_screen.dart';
import 'my_tickets_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'notice_screen.dart';
import '../constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _user = FirebaseAuth.instance.currentUser;
  String _firstName = "Student";
  String _walletBalance = "0.00";
  String? _studentId;
  bool _isLoadingProfile = true;
  bool _isRefreshing = false;
  int _currentNavIndex = 0;
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

  Future<void> _fetchProfile({bool silent = false}) async {
    if (_user?.email == null) return;
    if (!silent) setState(() => _isLoadingProfile = true);

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.profilesUrl}${Uri.encodeComponent(_user!.email!)}/'),
      ).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _firstName = data['first_name'] ?? "Student";
            _walletBalance = double.tryParse(data['wallet_balance'].toString())?.toStringAsFixed(2) ?? "0.00";
            _studentId = data['student_id'];
            _isLoadingProfile = false;
          });
          // Start Firebase listener only once we have the student_id
          if (_studentId != null) _listenToBalance(_studentId!);
        }
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  void _listenToBalance(String studentId) {
    _balanceSubscription?.cancel();
    _balanceSubscription = FirebaseDatabase.instance
        .ref('wallets/$studentId/balance')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        final balance = double.tryParse(event.snapshot.value.toString()) ?? 0.0;
        setState(() {
          _walletBalance = balance.toStringAsFixed(2);
        });
      }
    });
  }

  Future<void> _refreshBalance() async {
    setState(() => _isRefreshing = true);
    await _fetchProfile(silent: true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _sendSOS() async {
    if (_user?.email == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending SOS Alert..."), backgroundColor: Colors.orange),
    );
    try {
      final response = await http.post(
        Uri.parse(AppConfig.sosUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _user!.email, "message": "Emergency SOS from UniBus app"}),
      ).timeout(AppConfig.requestTimeout);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.statusCode == 201 ? "SOS Alert Sent!" : "Failed to send SOS"),
          backgroundColor: response.statusCode == 201 ? Colors.red : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error sending SOS"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D6A4F), Color(0xFF52B788)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Good day,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          _isLoadingProfile ? "Loading..." : _firstName,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _currentNavIndex = 3),
                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Wallet card
                GestureDetector(
                  onTap: _refreshBalance,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Wallet Balance", style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 4),
                            _isRefreshing
                                ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D6A4F)))
                                : Text(
                                    "৳ $_walletBalance",
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
                                  ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Color(0xFF52B788), size: 32),
                            const SizedBox(height: 4),
                            const Text("Tap to refresh", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildActionCard("Book Ticket", Icons.confirmation_number_outlined, const Color(0xFF52B788), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const BookTicketScreen()))
                          .then((_) => _fetchProfile(silent: true));
                    }),
                    _buildActionCard("My Tickets", Icons.qr_code, const Color(0xFF2D6A4F), () {
                      setState(() => _currentNavIndex = 1);
                    }),
                    _buildActionCard("Notices", Icons.notifications_outlined, const Color(0xFF40916C), () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticeScreen()));
                    }),
                    _buildActionCard("SOS Alert", Icons.emergency, Colors.red, _sendSOS),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHome(),
      MyTicketsScreen(onBookNew: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookTicketScreen()))),
      const HistoryScreen(),
      ProfileScreen(
        studentId: _studentId,
        walletBalance: _walletBalance,
        onProfileUpdated: () => _fetchProfile(silent: true),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: IndexedStack(index: _currentNavIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentNavIndex,
        onDestinationSelected: (i) => setState(() => _currentNavIndex = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF52B788).withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.qr_code_outlined), selectedIcon: Icon(Icons.qr_code), label: "Tickets"),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: "History"),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}