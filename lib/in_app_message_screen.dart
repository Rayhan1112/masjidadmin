
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class InAppMessageScreen extends StatefulWidget {
  const InAppMessageScreen({super.key});

  @override
  State<InAppMessageScreen> createState() => _InAppMessageScreenState();
}

class _InAppMessageScreenState extends State<InAppMessageScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _imageFile;

  // State for checkboxes
  bool _includeTitle = true;
  bool _includeDescription = true;
  bool _includeImage = true;

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

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
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
            // --- Configuration Checkboxes ---
            _buildConfigRow(
              label: 'Include Title',
              value: _includeTitle,
              onChanged: (val) => setState(() => _includeTitle = val!),
            ),
            _buildConfigRow(
              label: 'Include Description',
              value: _includeDescription,
              onChanged: (val) => setState(() => _includeDescription = val!),
            ),
            _buildConfigRow(
              label: 'Include Image',
              value: _includeImage,
              onChanged: (val) => setState(() => _includeImage = val!),
            ),
            const SizedBox(height: 24),

            // --- Input Fields ---
            if (_includeTitle)
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
            if (_includeTitle) const SizedBox(height: 16),
            if (_includeDescription)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            if (_includeDescription) const SizedBox(height: 16),
            if (_includeImage)
              OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: Text(_imageFile == null ? 'Select Image' : 'Change Image'),
                onPressed: _pickImage,
              ),
            const SizedBox(height: 32),

            // --- Preview Section ---
            Text(
              'PREVIEW',
              style: Theme.of(context).textTheme.labelMedium,
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

  Widget _buildConfigRow(
      {required String label, required bool value, required ValueChanged<bool?> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Checkbox(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildPreview() {
    final title = _titleController.text;
    final description = _descriptionController.text;

    // Do not show the card if no elements are included and the fields are empty.
    if ((!_includeTitle || title.isEmpty) &&
        (!_includeDescription || description.isEmpty) &&
        (!_includeImage || _imageFile == null)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Text('Preview will appear here', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Card(
      elevation: 4.0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_includeImage)
            Container(
              height: 150,
              color: Colors.grey[800],
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(
                        Icons.photo_size_select_actual_outlined,
                        color: Colors.white24,
                        size: 48.0,
                      ),
                    ),
            ),
          if ((_includeTitle && title.isNotEmpty) || (_includeDescription && description.isNotEmpty))
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_includeTitle && title.isNotEmpty)
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  if (_includeTitle && title.isNotEmpty && _includeDescription && description.isNotEmpty)
                    const SizedBox(height: 8),
                  if (_includeDescription && description.isNotEmpty)
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
