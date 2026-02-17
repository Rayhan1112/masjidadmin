import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TiffinOrdersScreen extends StatefulWidget {
  const TiffinOrdersScreen({super.key});

  @override
  State<TiffinOrdersScreen> createState() => _TiffinOrdersScreenState();
}

class _TiffinOrdersScreenState extends State<TiffinOrdersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Tiffin Orders", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSummaryHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tiffin_orders')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    
                    // IST Date for grouping
                    final istDate = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
                    final dateKey = DateFormat('yyyy-MM-dd').format(istDate);
                    
                    bool showDivider = false;
                    if (index == 0) {
                      showDivider = true;
                    } else {
                      final prevData = docs[index - 1].data() as Map<String, dynamic>;
                      final prevTs = (prevData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final prevIstDate = prevTs.toUtc().add(const Duration(hours: 5, minutes: 30));
                      final prevDateKey = DateFormat('yyyy-MM-dd').format(prevIstDate);
                      if (dateKey != prevDateKey) {
                        showDivider = true;
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDivider)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 16, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Text(
                                  _getFormattedDateHeader(istDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        _buildOrderCard(data, docId),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tiffin_orders').snapshots(),
      builder: (context, snapshot) {
        int total = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        // Count today's orders using IST (UTC+5:30)
        final nowUtc = DateTime.now().toUtc();
        final istTime = nowUtc.add(const Duration(hours: 5, minutes: 30));
        final startOfTodayIST = DateTime.utc(istTime.year, istTime.month, istTime.day).subtract(const Duration(hours: 5, minutes: 30));
        
        int todayCount = 0;
        if (snapshot.hasData) {
          todayCount = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = (data['timestamp'] as Timestamp?)?.toDate();
            // Compare timestamps in UTC terms
            return ts != null && ts.isAfter(startOfTodayIST);
          }).length;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF6366F1),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem("Total Orders", total.toString(), Icons.history),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem("Today's Orders", todayCount.toString(), Icons.today),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String docId) {
    final utcTimestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final istTimestamp = utcTimestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    final dateStr = DateFormat('MMM dd, yyyy').format(istTimestamp);
    final timeStr = DateFormat('hh:mm a').format(istTimestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                color: const Color(0xFF6366F1),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['name'] ?? 'Anonymous',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1E293B)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              timeStr,
                              style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(data['phone'] ?? 'N/A', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['address'] ?? 'No address',
                              style: const TextStyle(color: Colors.black87, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => _showOrderDetails(data, docId),
                            child: const Text(
                              "View Details",
                              style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            const Text("Order Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("ID: $docId", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(height: 32),
            _detailRow(Icons.person, "Customer Name", data['name'] ?? 'N/A'),
            _detailRow(Icons.phone, "Phone Number", data['phone'] ?? 'N/A'),
            _detailRow(Icons.location_on, "Delivery Address", data['address'] ?? 'N/A'),
            _detailRow(Icons.access_time_filled, "Ordered At", 
                DateFormat('MMM dd, yyyy - hh:mm a').format((data['timestamp'] as Timestamp).toDate().toUtc().add(const Duration(hours: 5, minutes: 30)))),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDateHeader(DateTime date) {
    // Current IST time
    final nowUtc = DateTime.now().toUtc();
    final istNow = nowUtc.add(const Duration(hours: 5, minutes: 30));
    
    final today = DateTime(istNow.year, istNow.month, istNow.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return "TODAY'S ORDERS";
    } else if (checkDate == yesterday) {
      return "YESTERDAY'S ORDERS";
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date).toUpperCase();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fastfood_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("No tiffin orders found", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
