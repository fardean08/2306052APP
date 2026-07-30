import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_client.dart';

/// UC4: Contact Supervisor About a Project (Student).
///
/// FR9: sends a message (>= 20 characters) about a specific idea/interest
/// entry; the backend links it to the entry and the sending student.
class ContactScreen extends StatefulWidget {
  final ApiClient apiClient;
  final Entry entry;

  const ContactScreen({
    super.key,
    required this.apiClient,
    required this.entry,
  });

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  static const _minMessageLength = 20;

  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.apiClient.post(
        '/api/entries/${widget.entry.id}/enquiries',
        body: {'message': _messageController.text.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message has been sent.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact supervisor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (widget.entry.description != null) ...[
                const SizedBox(height: 8),
                Text(widget.entry.description!),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Your message',
                  hintText:
                      'Introduce yourself and explain your interest in '
                      'this project (min. 20 characters).',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.length < _minMessageLength) {
                    return 'Message must be at least $_minMessageLength '
                        'characters (currently ${trimmed.length}).';
                  }
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send message'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
