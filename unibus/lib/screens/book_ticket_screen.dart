import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class BookTicketScreen extends StatefulWidget {
  const BookTicketScreen({super.key});

  @override
  State<BookTicketScreen> createState() => _BookTicketScreenState();
}

class _BookTicketScreenState extends State<BookTicketScreen> {
  final TextEditingController _boardingController = TextEditingController();
  final TextEditingController _droppingController = TextEditingController();

  bool _isSearched = false;
  bool _isLoading = false;
  List<dynamic> _busList = [];
  List<String> _boardingSuggestions = [];
  List<String> _droppingSuggestions = [];

  final String _baseUrl = 'http://192.168.0.103:8000/api/buses/';
  final String _ticketUrl = 'http://192.168.0.103:8000/api/tickets/';
  final String _suggestionUrl = 'http://192.168.0.103:8000/api/suggestions/';

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _boardingController.dispose();
    _droppingController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions() async {
    try {
      final response = await http.get(Uri.parse(_suggestionUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _boardingSuggestions = List<String>.from(data['boarding']);
          _droppingSuggestions = List<String>.from(data['dropping']);
        });
      }
    } catch (e) {
      debugPrint("Suggestion fetching error: $e");
    }
  }

  Future<void> _handleSearch() async {
    FocusScope.of(context).unfocus();
    if (_boardingController.text.isEmpty || _droppingController.text.isEmpty) {
      _showSnackBar('Please enter both boarding and dropping points', Colors.redAccent);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearched = true;
    });

    try {
      final url = Uri.parse(
        '$_baseUrl?boarding=${Uri.encodeComponent(_boardingController.text)}'
        '&dropping=${Uri.encodeComponent(_droppingController.text)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _busList = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        _showError("Failed to load time slots.");
      }
    } catch (e) {
      _showError("Connection error. Check your server.");
    }
  }

  Future<void> _bookTicket(Map<String, dynamic> bus) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ✅ FIX: full email পাঠাও — Django এটা দিয়ে StudentProfile খুঁজবে
    final String userEmail = user.email!;

    try {
      final response = await http.post(
        Uri.parse(_ticketUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,   // full email — যেমন reachad22205101708@diu.edu.bd
          "bus_id": bus['id'],
        }),
      );

      if (mounted) {
        if (response.statusCode == 201) {
          _showSnackBar("Ticket booked successfully!", Colors.green);
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

  void _confirmBooking(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Booking"),
        content: Text(
          "Do you want to book a seat for the ${bus['formatted_time']} slot?",
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
              _bookTicket(bus);
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Select Slot",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildAutocompleteField(
                  "BOARDING POINT",
                  _boardingController,
                  _boardingSuggestions,
                ),
                const SizedBox(height: 15),
                _buildAutocompleteField(
                  "DROPPING POINT",
                  _droppingController,
                  _droppingSuggestions,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: 160,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSearch,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                    label: const Text(
                      "Search Slot",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69AD8E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF69AD8E)),
                  )
                : !_isSearched
                    ? const Center(
                        child: Text(
                          "Select points to see available slots",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _busList.isEmpty
                        ? const Center(
                            child: Text(
                              "No slots available.",
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _busList.length,
                            itemBuilder: (context, index) {
                              final bus = _busList[index];
                              return GestureDetector(
                                onTap: () => _confirmBooking(bus),
                                child: _buildSlotCard(bus),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> bus) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "DEPARTURE TIME",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                bus["formatted_time"] ?? "--",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF69AD8E),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "AVAILABLE SEATS",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${bus["available_seats"]}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutocompleteField(
    String hint,
    TextEditingController mainController,
    List<String> options,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
          return options.where(
            (String option) => option.toLowerCase().contains(
              textEditingValue.text.toLowerCase(),
            ),
          );
        },
        onSelected: (String selection) {
          mainController.text = selection;
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
          if (fieldController.text != mainController.text) {
            fieldController.text = mainController.text;
          }
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12),
            ),
          );
        },
      ),
    );
  }
}