import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';
import 'checker_dashboard_screen.dart';
import 'signup_screen.dart';
import '../constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Please fill all fields", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign in using Firebase Authentication
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        _showMessage("Login Successful! Fetching profile...", Colors.green);
        
        // Fetch role from Django backend
        try {
          final response = await http.get(
            Uri.parse('${AppConfig.profilesUrl}$email/'),
          ).timeout(AppConfig.requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final role = data['role'] ?? 'Student';
            
            if (role == 'Checker') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CheckerDashboardScreen(
                  checkerName: data['first_name'] ?? "Checker",
                  checkerEmail: data['email'] ?? email,
                )),
              );
            } else if (role == 'Vendor') {
              _showMessage("Vendor should use the Web Panel", Colors.orange);
              // Or navigate to a specific Vendor app screen
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            }
          } else {
            // Default to student if backend profile not found (might happen if sync failed)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        } catch (e) {
          // If backend fetch fails, default to Student Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // If Firebase login fails, try the Custom Backend Login (for Staff/Checkers)
      try {
        final customResponse = await http.post(
          Uri.parse(AppConfig.loginUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        ).timeout(AppConfig.requestTimeout);

        if (customResponse.statusCode == 200) {
          final data = jsonDecode(customResponse.body);
          final role = data['role'];
          
          if (mounted) {
            _showMessage("Staff Login Successful!", Colors.green);
            if (role == 'Checker') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => CheckerDashboardScreen(
                  checkerName: data['first_name'] ?? "Checker",
                  checkerEmail: data['email'] ?? email,
                )),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            }
          }
          return;
        }
      } catch (backendError) {
        debugPrint("Backend login attempt failed: $backendError");
      }

      String errorMessage = "Login failed";
      if (e.code == 'user-not-found') {
        errorMessage = "User not found. If you are a student, please sign up.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Wrong password provided.";
      } else {
        errorMessage = e.message ?? "Authentication failed";
      }
      _showMessage(errorMessage, Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                Image.asset(
                  'assets/images/logo.png',
                  width: 200, 
                  height: 200, 
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.directions_bus, 
                      size: 150, 
                      color: Color(0xFF69AD8E)
                    );
                  },
                ),
                
                const SizedBox(height: 40),

                // Email Input
                _buildTextField(_emailController, "Email Address", Icons.email_outlined),
                const SizedBox(height: 20),

                // Password Input
                _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                const SizedBox(height: 35),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69AD8E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 30),

                // Navigation to Sign Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: TextStyle(color: Colors.black54)),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                      child: const Text("Sign Up", style: TextStyle(color: Color(0xFF69AD8E), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
      ),
    );
  }
}