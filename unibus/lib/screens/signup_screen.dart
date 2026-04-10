import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _handleSignUp() async {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String studentId = _studentIdController.text.trim();
    String mobile = _mobileController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || studentId.isEmpty || 
        mobile.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage("Please fill in all fields", Colors.redAccent);
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match!", Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Firebase Auth Step
      debugPrint("Starting Firebase Registration...");
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String? firebaseUid = userCredential.user?.uid;
      debugPrint("Firebase Success. UID: $firebaseUid");

      // 2. Django Sync Step (UPDATED IP: 192.168.0.109)
      const String apiUrl = "http://192.168.0.109:8000/api/students/"; 
      
      debugPrint("Connecting to Django at: $apiUrl");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": firstName,
          "last_name": lastName,
          "student_id": studentId,
          "mobile_number": mobile,
          "email": email,
          "firebase_uid": firebaseUid, 
        }),
      ).timeout(const Duration(seconds: 15)); // Increased timeout

      debugPrint("Django Response Code: ${response.statusCode}");

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showMessage("Registration Successful!", Colors.green);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        });
      } else {
        // Handle Django Validation Errors (e.g. Unique ID error)
        var errorBody = jsonDecode(response.body);
        debugPrint("Django Error: $errorBody");
        _showMessage("Server Sync Failed! Check if ID is unique.", Colors.orange);
      }

    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Error: ${e.message}");
      _showMessage(e.message ?? "Firebase Registration failed", Colors.redAccent);
    } catch (e) {
      debugPrint("Network Error: $e");
      _showMessage("Connection Error: Check Server IP & Network", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Sign Up"), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Icon(Icons.person_add, size: 60, color: Color(0xFF69AD8E)),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(child: _buildTextField(_firstNameController, "First Name", Icons.person_outline)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField(_lastNameController, "Last Name", Icons.person_outline)),
              ],
            ),
            const SizedBox(height: 15),

            _buildTextField(_studentIdController, "Student ID", Icons.badge_outlined, isNumber: true),
            const SizedBox(height: 15),

            _buildTextField(_mobileController, "Mobile Number", Icons.phone_android, isNumber: true),
            const SizedBox(height: 15),

            _buildTextField(_emailController, "Email Address", Icons.email_outlined),
            const SizedBox(height: 15),

            _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
            const SizedBox(height: 15),

            _buildTextField(_confirmPasswordController, "Confirm Password", Icons.lock_reset, isPassword: true),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF69AD8E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}