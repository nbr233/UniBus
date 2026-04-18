/// UniBus App — Central Configuration
/// সব স্ক্রিন এখান থেকে baseUrl নেবে।
/// IP পরিবর্তন করতে হলে শুধু এই ফাইলেই করতে হবে।
class AppConfig {
  // Local Development Server IP
  // ⚠️ Production Render URL হলে এটি পরিবর্তন করো:
  // static const String baseUrl = 'https://your-app.onrender.com';
  static const String baseUrl = 'http://192.168.0.101:8000';
  static const String firebaseDbUrl = 'https://unibus-app-e8e4b-default-rtdb.firebaseio.com';

  // API Endpoints
  static const String studentsUrl = '$baseUrl/api/students/';
  static const String loginUrl = '$baseUrl/api/login/';
  static const String busesUrl = '$baseUrl/api/buses/';
  static const String routesUrl = '$baseUrl/api/routes/';
  static const String masterRoutesUrl = '$baseUrl/api/master-routes/';
  static const String ticketsUrl = '$baseUrl/api/tickets/';
  static const String suggestionsUrl = '$baseUrl/api/suggestions/';
  static const String profilesUrl = '$baseUrl/api/students/';
  static const String noticesUrl = '$baseUrl/api/notices/';
  static const String sosUrl = '$baseUrl/api/sos/';
  static const String validateTicketUrl = '$baseUrl/api/validate-ticket/';

  // University email domain (Validation-এর জন্য)
  static const String universityEmailDomain = '@diu.edu.bd';

  // Request Timeout
  static const Duration requestTimeout = Duration(seconds: 15);
}
