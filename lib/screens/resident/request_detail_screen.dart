import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/report_reasons.dart';
import '../../models/vendor_request.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final VendorRequest request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Future<void> _reportVendor() async {
    final resident = context.read<AppProvider>().currentUser;
    if (resident == null) return;

    String? selectedReason;
    final detailsController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report Vendor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reportReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => selectedReason = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(labelText: 'Details (Optional)', border: OutlineInputBorder()),
                  maxLines: 3,
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (selectedReason != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null) {
      try {
        await FirestoreService().createReport(
          reporterId: resident.id,
          reporterName: resident.name,
          reportedUserId: widget.request.vendorId,
          reportedUserName: widget.request.vendorName,
          requestId: widget.request.id,
          reason: selectedReason!,
          details: detailsController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted successfully')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit report: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Detail'),
        actions: [
          IconButton(icon: const Icon(Icons.report_problem_outlined), onPressed: _reportVendor, tooltip: 'Report Vendor'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard('To Vendor', req.vendorName),
          _buildCard('Question', req.question),
          if (req.itemName.isNotEmpty) _buildCard('Item Name', req.itemName),
          if (req.extraDetails.isNotEmpty) _buildCard('Extra Details', req.extraDetails),
          const SizedBox(height: 16),
          const Text('Response', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (req.status == 'answered')
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(req.response, style: const TextStyle(fontSize: 16)),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Waiting for vendor response...', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(content, style: const TextStyle(fontSize: 16)),
          const Divider(),
        ],
      ),
    );
  }
}
