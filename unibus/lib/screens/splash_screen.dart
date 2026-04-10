import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 2. Setup Animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // 3. Start Navigation Logic
    _navigateToNext();
  }

  // Fixed Navigation Logic with Error Handling
  void _navigateToNext() {
    Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;

      try {
        // Check if user is logged in via Firebase
        User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // Navigate to Dashboard if session exists
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else {
          // Navigate to Login if no session
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } catch (e) {
        // Fallback: If Firebase is not configured (like on Web), go to Login Screen
        debugPrint("Firebase Navigation Error: $e");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display Logo with a fallback if image is missing
                Image.asset(
                  'assets/images/logo.png', 
                  width: 200,
                  errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.directions_bus, size: 100, color: Color(0xFF69AD8E)),
                ),
                const SizedBox(height: 15),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}