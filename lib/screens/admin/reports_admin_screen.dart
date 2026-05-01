import 'package:flutter/material.dart';
import '../../models/user_report.dart';
import '../../services/firestore_service.dart';

class ReportsAdminScreen extends StatelessWidget {
  const ReportsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Reports')),
      body: StreamBuilder(
        stream: FirestoreService().reportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No reports found.'));

          final reports = docs.map((d) => UserReport.fromMap(d.id, d.data())).toList();
          reports.sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
          });

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status: ${report.status.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: report.status == 'pending' ? Colors.red : Colors.green)),
                          Text(report.createdAt?.toString().split('.').first ?? ''),
                        ],
                      ),
                      const Divider(),
                      Text('Reporter: ${report.reporterName}'),
                      Text('Reported User: ${report.reportedUserName}'),
                      Text('Reason: ${report.reason}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (report.details.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Details: ${report.details}'),
                      ],
                      if (report.requestId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Request ID: ${report.requestId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                      const SizedBox(height: 16),
                      if (report.status != 'resolved')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (report.status == 'pending')
                              TextButton(
                                onPressed: () => FirestoreService().updateReportStatus(report.id, 'reviewed'),
                                child: const Text('Mark Reviewed'),
                              ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => FirestoreService().updateReportStatus(report.id, 'resolved'),
                              child: const Text('Mark Resolved'),
                            ),
                          ],
                        )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
