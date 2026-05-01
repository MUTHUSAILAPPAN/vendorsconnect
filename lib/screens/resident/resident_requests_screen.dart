import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_request.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import 'request_detail_screen.dart';

class ResidentRequestsScreen extends StatelessWidget {
  const ResidentRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final resident = context.watch<AppProvider>().currentUser;
    if (resident == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder(
        stream: FirestoreService().residentRequestsStream(resident.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('You have not made any requests yet.'));
          }

          final requests = docs.map((d) => VendorRequest.fromMap(d.id, d.data())).toList();
          requests.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return ListTile(
                title: Text('To: ${req.vendorName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.question),
                    if (req.status == 'answered')
                      Text('Status: Answered', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))
                    else
                      Text('Status: ${req.status}', style: const TextStyle(color: Colors.orange)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(request: req)));
                },
              );
            },
          );
        },
      ),
    );
  }
}
