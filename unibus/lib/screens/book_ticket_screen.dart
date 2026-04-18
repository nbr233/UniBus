import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../constants.dart';

class BookTicketScreen extends StatefulWidget {
  final bool isPreBooking;
  const BookTicketScreen({super.key, this.isPreBooking = false});

  @override
  State<BookTicketScreen> createState() => _BookTicketScreenState();
}

class _BookTicketScreenState extends State<BookTicketScreen> {
  bool _isLoading = true;
  List<dynamic> _routeList = [];
  List<dynamic> _filteredRoutes = [];
  List<String> _bookedDates = [];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final TextEditingController _boardingController = TextEditingController();
  final TextEditingController _droppingController = TextEditingController();
  TimeOfDay? _desiredTime;
  List<dynamic> _masterRoutes = [];
  Map<String, dynamic>? _selectedMasterRoute;

  final String _routesUrl = AppConfig.routesUrl;
  final String _ticketUrl = AppConfig.ticketsUrl;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
    _fetchBookedDates();
    if (widget.isPreBooking) {
      _fetchMasterRoutes();
    }
    
    _boardingController.addListener(_filterRoutes);
    _droppingController.addListener(_filterRoutes);
  }

  Future<void> _fetchMasterRoutes() async {
    try {
      final response = await http.get(Uri.parse(AppConfig.masterRoutesUrl))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _masterRoutes = jsonDecode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Master routes fetch error: $e");
    }
  }

  @override
  void dispose() {
    _boardingController.dispose();
    _droppingController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoutes() async {
    try {
      final response = await http.get(Uri.parse(_routesUrl))
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _routeList = jsonDecode(response.body);
            _filteredRoutes = List.from(_routeList);
            _isLoading = false;
          });
        }
      } else {
        _showError("Failed to load routes.");
      }
    } catch (e) {
      _showError("Connection error.");
    }
  }

  Future<void> _fetchBookedDates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final baseUrl = _ticketUrl.endsWith('/') ? _ticketUrl.substring(0, _ticketUrl.length - 1) : _ticketUrl;
      final url = Uri.parse('$baseUrl/booked_dates/?student_id=${Uri.encodeComponent(user.email!)}');
      final response = await http.get(url).timeout(AppConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _bookedDates = List<String>.from(jsonDecode(response.body));
          });
        }
      }
    } catch (e) {
      // Silently fail or log
    }
  }

  void _filterRoutes() {
    final boardingQuery = _boardingController.text.toLowerCase();
    final droppingQuery = _droppingController.text.toLowerCase();

    setState(() {
      _filteredRoutes = _routeList.where((route) {
        final boarding = route['boarding_point'].toString().toLowerCase();
        final dropping = route['dropping_point'].toString().toLowerCase();
        return boarding.contains(boardingQuery) && dropping.contains(droppingQuery);
      }).toList();
    });
  }

  Future<void> _bookTicket({Map<String, dynamic>? route}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pre-booking mode: needs master route + desired time
    if (widget.isPreBooking) {
      if (_selectedMasterRoute == null || _desiredTime == null) {
        _showSnackBar("Please select a Route and your preferred Travel Time", Colors.orange);
        return;
      }
    } else {
      // Direct booking from route list
      if (route == null) {
        _showSnackBar("Please select a route from the list", Colors.orange);
        return;
      }
    }

    setState(() => _isLoading = true);

    final String userEmail = user.email!;
    final travelDateStr =
        "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";

    String? desiredTimeStr;
    if (_desiredTime != null) {
      final hour = _desiredTime!.hour.toString().padLeft(2, '0');
      final minute = _desiredTime!.minute.toString().padLeft(2, '0');
      desiredTimeStr = "$hour:$minute";
    }

    try {
      final Map<String, dynamic> body = {
        "user_email": userEmail,
        "travel_date": travelDateStr,
      };

      if (widget.isPreBooking) {
        // Pre-booking: use master_route_id + desired_time
        body["master_route_id"] = _selectedMasterRoute!['id'];
        if (desiredTimeStr != null) body["desired_time"] = desiredTimeStr;
      } else {
        // Direct booking from schedule list: use master_route_id from route
        body["master_route_id"] = route!['master_route'];
        if (desiredTimeStr != null) body["desired_time"] = desiredTimeStr;
      }

      final response = await http.post(
        Uri.parse(_ticketUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(AppConfig.requestTimeout);

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final routeName = data['master_route_details']?['name'] ?? "your route";
          _showSnackBar(
            widget.isPreBooking
                ? "Booked! A bus will be assigned closer to your time."
                : "Ticket booked for $routeName!",
            Colors.green,
          );
          _fetchBookedDates();
          if (widget.isPreBooking) {
            setState(() {
              _selectedMasterRoute = null;
              _desiredTime = null;
            });
          }
        } else {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          _showSnackBar(responseData['error'] ?? "Booking failed", Colors.redAccent);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showSnackBar("Network error.", Colors.redAccent);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _desiredTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _desiredTime) {
      setState(() {
        _desiredTime = picked;
      });
    }
  }

  void _confirmBooking(Map<String, dynamic> route) {
    final dateStr = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Booking"),
        content: Text(
          "Do you want to buy a ticket for:\n\nRoute: ${route['name']}\nDate: $dateStr\nFare: ৳${route['fare']}",
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
              _bookTicket(route: route);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String m) {
    if (mounted) setState(() => _isLoading = false);
    _showSnackBar(m, Colors.redAccent);
  }

  void _showSnackBar(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: c,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Travel Planner",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _isLoading && _routeList.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF69AD8E)),
            )
          : Column(
              children: [
                // Calendar Section
                Container(
                  color: const Color(0xFFF8FAF9),
                  child: TableCalendar(
                    firstDay: DateTime.now(), // Cannot book past dates
                    lastDay: DateTime.now().add(const Duration(days: 30)), // Book up to 30 days in advance
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.week,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Color(0xFFB4D8C6),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF69AD8E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
                        if (_bookedDates.contains(dateStr)) {
                          return Container(
                            margin: const EdgeInsets.all(6.0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF69AD8E), width: 2),
                            ),
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF69AD8E)),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                
                // ── SEARCH / SELECTION SECTION ──
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: widget.isPreBooking 
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Select Route", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Map<String, dynamic>>(
                                isExpanded: true,
                                hint: const Text("Select a Route"),
                                value: _selectedMasterRoute,
                                items: _masterRoutes.map((m) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: m,
                                    child: Text(m['name']),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedMasterRoute = val),
                              ),
                            ),
                          ),
                          if (_selectedMasterRoute != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              "Fare: ৳${_selectedMasterRoute!['fare']} (${_selectedMasterRoute!['boarding_point']} → ${_selectedMasterRoute!['dropping_point']})",
                              style: const TextStyle(color: Color(0xFF69AD8E), fontWeight: FontWeight.bold),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _selectTime(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, color: Color(0xFF69AD8E), size: 20),
                                        const SizedBox(width: 8),
                                        Text(_desiredTime == null ? "Select Time" : "Time: ${_desiredTime!.format(context)}"),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isLoading ? null : () => _bookTicket(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C3E50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                child: const Text("Book Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _boardingController,
                                  decoration: InputDecoration(
                                    hintText: "From (e.g. DSC)",
                                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF69AD8E)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _droppingController,
                                  decoration: InputDecoration(
                                    hintText: "To (e.g. Dhanmondi)",
                                    prefixIcon: const Icon(Icons.flag_outlined, color: Color(0xFF69AD8E)),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                ),

                // ── TICKET LIST SECTION (Only for Single Journey) ──
                if (!widget.isPreBooking) ...[
                  if (_isLoading)
                    const Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF69AD8E))),
                  Expanded(
                    child: _filteredRoutes.isEmpty && !_isLoading
                        ? const Center(child: Text("No routes found for today.", style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredRoutes.length,
                            itemBuilder: (context, index) {
                              final route = _filteredRoutes[index];
                              return GestureDetector(
                                onTap: () => _confirmBooking(route),
                                child: _buildRouteCard(route),
                              );
                            },
                          ),
                  ),
                ] else
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              "Your travel time will be matched with the best schedule the day before your journey.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: const Color(0xFF69AD8E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route["name"],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.trip_origin, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        route['boarding_point'],
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Color(0xFF69AD8E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        route['dropping_point'],
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (route['schedule_time'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69AD8E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF69AD8E)),
                        const SizedBox(width: 4),
                        Text(
                          route['schedule_time'],
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF69AD8E)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "৳${route["fare"]}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF69AD8E),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF69AD8E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Book",
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}