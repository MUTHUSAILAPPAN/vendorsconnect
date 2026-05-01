import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/request_questions.dart';
import '../../models/app_user.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';

class VendorRequestScreen extends StatefulWidget {
  final AppUser vendor;

  const VendorRequestScreen({super.key, required this.vendor});

  @override
  State<VendorRequestScreen> createState() => _VendorRequestScreenState();
}

class _VendorRequestScreenState extends State<VendorRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedQuestion;
  final _itemNameController = TextEditingController();
  final _extraDetailsController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _itemNameController.dispose();
    _extraDetailsController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedQuestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a question')));
      return;
    }

    final resident = context.read<AppProvider>().currentUser;
    if (resident == null) return;

    setState(() => _loading = true);

    try {
      await FirestoreService().createVendorRequest(
        residentId: resident.id,
        residentName: resident.name,
        vendorId: widget.vendor.id,
        vendorName: widget.vendor.name,
        question: _selectedQuestion!,
        itemName: _itemNameController.text.trim(),
        extraDetails: _extraDetailsController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent successfully')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send request: ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ask ${widget.vendor.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('What would you like to ask?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Question', border: OutlineInputBorder()),
              initialValue: _selectedQuestion,
              items: requestQuestions.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
              onChanged: (v) => setState(() => _selectedQuestion = v),
              validator: (v) => v == null ? 'Please select a question' : null,
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: 'Item Name (Optional)',
                hintText: 'e.g. Apples, Ice Cream',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _extraDetailsController,
              decoration: const InputDecoration(
                labelText: 'Extra Details (Optional)',
                hintText: 'Any specific requirements or location info...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _submitRequest,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
              label: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}
