import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_request.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'vendor_request_detail_screen.dart';

class VendorRequestsScreen extends StatelessWidget {
  const VendorRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vendor = context.watch<AppProvider>().currentUser;
    if (vendor == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      body: StreamBuilder(
        stream: FirestoreService().vendorRequestsStream(vendor.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('You have no requests yet.'));
          }

          final requests = docs.map((d) => VendorRequest.fromMap(d.id, d.data())).toList();
          
          // Sort: pending first, then by date descending
          requests.sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
          });

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final isPending = req.status == 'pending';
              return ListTile(
                tileColor: isPending ? Colors.orange.withValues(alpha: 0.1) : null,
                leading: CircleAvatar(
                  backgroundColor: isPending ? Colors.orange : Colors.grey,
                  child: Icon(isPending ? Icons.mark_chat_unread : Icons.chat, color: Colors.white, size: 18),
                ),
                title: Text(req.residentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(req.question, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VendorRequestDetailScreen(request: req)));
                },
              );
            },
          );
        },
      ),
    );
  }
}
