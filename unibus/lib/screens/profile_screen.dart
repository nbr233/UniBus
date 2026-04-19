import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import '../constants.dart';
import 'login_screen.dart';
import 'lost_and_found_screen.dart'; // [NEW] Import

class ProfileScreen extends StatelessWidget {
  final String? studentId;
  final String walletBalance;
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({
    super.key,
    this.studentId,
    this.walletBalance = "0.00",
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
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
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? (user?.email?.split('@').first ?? "Student"),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Wallet balance with live Firebase listener
                _LiveBalanceCard(studentId: studentId, initialBalance: walletBalance),
              ],
            ),
          ),

          // ── Info tiles ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _InfoTile(label: "Student ID", value: studentId ?? "Not linked", icon: Icons.badge_outlined),
                _InfoTile(label: "Email", value: user?.email ?? "—", icon: Icons.email_outlined),
                const SizedBox(height: 10),
                
                // ── [NEW] Lost & Found Menu ──
                _MenuTile(
                  label: "Lost & Found",
                  icon: Icons.search_off_rounded,
                  color: Colors.orange[700]!,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LostAndFoundScreen()),
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                _InfoTile(label: "App Version", value: "UniBus v1.0", icon: Icons.info_outlined),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _LiveBalanceCard extends StatefulWidget {
  final String? studentId;
  final String initialBalance;
  const _LiveBalanceCard({this.studentId, required this.initialBalance});

  @override
  State<_LiveBalanceCard> createState() => _LiveBalanceCardState();
}

class _LiveBalanceCardState extends State<_LiveBalanceCard> {
  late String _balance;
  StreamSubscription<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
    _startListening();
  }

  void _startListening() {
    if (widget.studentId == null) return;
    _sub = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: AppConfig.firebaseDbUrl)
        .ref('wallets/${widget.studentId}/balance')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && mounted) {
        final val = double.tryParse(event.snapshot.value.toString()) ?? 0.0;
        setState(() => _balance = val.toStringAsFixed(2));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Wallet Balance", style: TextStyle(color: Colors.white70)),
          Text("৳ $_balance", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF52B788), size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}