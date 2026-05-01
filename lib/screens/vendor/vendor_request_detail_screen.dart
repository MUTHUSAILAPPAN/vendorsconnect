import 'package:flutter/material.dart';

import '../../models/vendor_request.dart';
import '../../services/firestore_service.dart';

class VendorRequestDetailScreen extends StatefulWidget {
  final VendorRequest request;
  const VendorRequestDetailScreen({super.key, required this.request});

  @override
  State<VendorRequestDetailScreen> createState() => _VendorRequestDetailScreenState();
}

class _VendorRequestDetailScreenState extends State<VendorRequestDetailScreen> {
  final _responseController = TextEditingController();
  bool _loading = false;
  late VendorRequest request;

  @override
  void initState() {
    super.initState();
    request = widget.request;
    _responseController.text = request.response;
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final response = _responseController.text.trim();
    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply cannot be empty')));
      return;
    }

    setState(() => _loading = true);
    try {
      await FirestoreService().replyToVendorRequest(request.id, response);
      if (!mounted) return;
      setState(() {
        request = VendorRequest(
          id: request.id,
          residentId: request.residentId,
          residentName: request.residentName,
          vendorId: request.vendorId,
          vendorName: request.vendorName,
          question: request.question,
          itemName: request.itemName,
          extraDetails: request.extraDetails,
          response: response,
          status: 'answered',
          createdAt: request.createdAt,
          respondedAt: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reply: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeRequest() async {
    setState(() => _loading = true);
    try {
      await FirestoreService().closeVendorRequest(request.id);
      if (!mounted) return;
      setState(() {
        request = VendorRequest(
          id: request.id,
          residentId: request.residentId,
          residentName: request.residentName,
          vendorId: request.vendorId,
          vendorName: request.vendorName,
          question: request.question,
          itemName: request.itemName,
          extraDetails: request.extraDetails,
          response: request.response,
          status: 'closed',
          createdAt: request.createdAt,
          respondedAt: request.respondedAt,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request closed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not close request: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard('From Resident', request.residentName),
          _buildCard('Question', request.question),
          if (request.itemName.isNotEmpty) _buildCard('Item Name', request.itemName),
          if (request.extraDetails.isNotEmpty) _buildCard('Extra Details', request.extraDetails),
          const SizedBox(height: 24),
          
          if (request.status != 'closed') ...[
            TextField(
              controller: _responseController,
              decoration: const InputDecoration(labelText: 'Your Reply', border: OutlineInputBorder()),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _submitReply,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Reply'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _closeRequest,
                  child: const Text('Close'),
                )
              ],
            )
          ] else ...[
            Card(
              color: Colors.grey.shade100,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('This request is closed.', style: TextStyle(fontStyle: FontStyle.italic)),
              ),
            )
          ]
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
