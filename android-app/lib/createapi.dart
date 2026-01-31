import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateApiScreen extends StatefulWidget {
  const CreateApiScreen({super.key});

  @override
  State<CreateApiScreen> createState() => _CreateApiScreenState();
}

class _CreateApiScreenState extends State<CreateApiScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  String? _generatedKey;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _generateNewKey();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Generate a random 16-digit alphanumeric key
  void _generateNewKey() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    String key = String.fromCharCodes(Iterable.generate(
        16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    
    // Optional: Add a standard prefix for clarity (e.g., sk_live_)
    // For this prompt, we keep it strictly 16 chars as requested.
    setState(() {
      _generatedKey = key;
    });
  }

  Future<void> _createApi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      // 1. Create the document in the 'organizations' collection
      // (This aligns with your main.dart so the dashboard can list it)
      await FirebaseFirestore.instance.collection('organizations').add({
        'name': _nameController.text.trim(),
        'apiKey': _generatedKey,
        'migrationStage': 'OLD', // Default starting stage for migration
        'isActive': true,
        'errorRate': 0.0, // Initial AI observation metric
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 2. Show Success Dialog (Inspired by your upload)
      _showSuccessDialog();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating API: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _isCreating = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('API Created', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merchant organization successfully registered.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'API KEY (Copy now):',
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: Colors.tealAccent
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generatedKey!,
                      style: const TextStyle(
                        fontFamily: 'Courier', // Monospace for keys
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.grey, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedKey!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Key copied to clipboard")),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ This key acts as the password for this merchant. Do not share it publicly.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to Dashboard
            },
            child: const Text('Done', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provision New API"),
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Area
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.tealAccent.shade700, Colors.blueGrey],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: const Icon(Icons.vpn_key_rounded, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 32),

                // Organization Name Input
                const Text(
                  "Organization Name",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? "Name is required" : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    hintText: "e.g. Acme Corp",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.tealAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Generated Key Display
                const Text(
                  "Generated API Key",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Auto-Generated Token",
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _generatedKey ?? "Generating...",
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _generateNewKey,
                        icon: const Icon(Icons.refresh, color: Colors.tealAccent),
                        tooltip: "Regenerate Key",
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createApi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Provision Organization",
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}