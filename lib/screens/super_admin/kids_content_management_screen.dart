import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KidsContentManagementScreen extends StatefulWidget {
  const KidsContentManagementScreen({super.key});

  @override
  State<KidsContentManagementScreen> createState() => _KidsContentManagementScreenState();
}

class _KidsContentManagementScreenState extends State<KidsContentManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, String>> _categories = [
    {'id': 'kids_duas', 'label': 'Duas', 'icon': '祈'},
    {'id': 'kids_quizzes', 'label': 'Quizzes', 'icon': '❓'},
    {'id': 'kids_stories', 'label': 'Stories', 'icon': '📚'},
    {'id': 'arabic_lessons', 'label': 'Lessons', 'icon': '☪️'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({String? collection, DocumentSnapshot? doc}) {
    final isEditing = doc != null;
    final data = isEditing ? doc.data() as Map<String, dynamic> : {};
    
    final titleController = TextEditingController(text: data['title'] ?? '');
    final contentController = TextEditingController(text: data['content'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Item" : "Add New Item"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: "Content / Description"),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty) return;

              final Map<String, dynamic> newData = {
                'title': title,
                'content': content,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              if (!isEditing) {
                newData['createdAt'] = FieldValue.serverTimestamp();
                await _db.collection(collection!).add(newData);
              } else {
                await _db.collection(collection!).doc(doc.id).update(newData);
              }

              if (mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? "UPDATE" : "ADD"),
          ),
        ],
      ),
    );
  }

  void _deleteItem(String collection, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Item?"),
        content: const Text("Are you sure you want to remove this item? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              await _db.collection(collection).doc(docId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Kids Content Management"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _categories.map((cat) => Tab(text: cat['label'])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((cat) => _buildContentList(cat['id']!)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(collection: _categories[_tabController.index]['id']),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContentList(String collection) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection(collection).orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("No items found in $collection", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'No Title';
            final content = data['content'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showAddEditDialog(collection: collection, doc: doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteItem(collection, doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
