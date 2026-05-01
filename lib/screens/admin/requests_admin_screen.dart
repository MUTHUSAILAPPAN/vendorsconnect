import 'package:flutter/material.dart';
import '../../models/vendor_request.dart';
import '../../services/firestore_service.dart';

class RequestsAdminScreen extends StatelessWidget {
  const RequestsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Vendor Requests')),
      body: StreamBuilder(
        stream: FirestoreService().allVendorRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No requests found.'));

          final requests = docs.map((d) => VendorRequest.fromMap(d.id, d.data())).toList();
          requests.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return ListTile(
                title: Text('${req.residentName} → ${req.vendorName}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (req.response.isNotEmpty) Text('Response: ${req.response}'),
                  ],
                ),
                trailing: Text(req.status, style: TextStyle(color: req.status == 'pending' ? Colors.orange : Colors.green)),
                isThreeLine: req.response.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
