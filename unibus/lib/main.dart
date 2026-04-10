import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart'; 
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/book_ticket_screen.dart';
import 'screens/profile_screen.dart'; // নতুন প্রোফাইল স্ক্রিন ইমপোর্ট করুন

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  
  runApp(const UniBusApp());
}

class UniBusApp extends StatelessWidget {
  const UniBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniBus',
      theme: ThemeData(
        primaryColor: const Color(0xFF69AD8E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF69AD8E),
          primary: const Color(0xFF69AD8E),
        ),
        useMaterial3: true,
        // টেক্সট ফিল্ডের জন্য গ্লোবাল স্টাইল (ঐচ্ছিক)
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF69AD8E)),
          ),
        ),
      ),
      
      home: const SplashScreen(), 
      
      // রাউটস আপডেট করা হয়েছে
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/book-ticket': (context) => const BookTicketScreen(),
        '/profile': (context) => const ProfileScreen(), // প্রোফাইল রাউট যোগ করা হলো
      },
    );
  }
}