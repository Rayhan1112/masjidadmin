
import 'dart:io';

import 'package:flutter/material.dart';

class InAppMessageScreen extends StatefulWidget {
  const InAppMessageScreen({super.key});

  @override
  State<InAppMessageScreen> createState() => _InAppMessageScreenState();
}

class _InAppMessageScreenState extends State<InAppMessageScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  // In a real app, you'd use a package like image_picker to get an image file.
  File? _image;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _pickImage() {
    // This is where you would implement image picking logic.
    // For this example, we'll simulate picking by setting a placeholder.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selection is not implemented in this example.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create In-App Message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Input Fields ---
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.image_outlined),
              label: const Text('Select Image'),
              onPressed: _pickImage,
            ),
            const SizedBox(height: 32),

            // --- Preview Section ---
            Text(
              'PREVIEW',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(height: 16),
            _buildPreview(),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('In-app message sent!')),
                  );
              },
              child: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }

  // This widget builds the visual preview of the in-app message.
  Widget _buildPreview() {
    final title = _titleController.text;
    final description = _descriptionController.text;

    return Card(
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero, // Remove default card margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image placeholder
          Container(
            height: 150,
            color: Colors.grey[300],
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : const Center(
                    child: Icon(
                      Icons.photo_size_select_actual_outlined,
                      color: Colors.black45,
                      size: 48.0,
                    ),
                  ),
          ),
          // Text content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                if (title.isNotEmpty && description.isNotEmpty) const SizedBox(height: 8),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

