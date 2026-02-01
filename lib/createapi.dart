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
  
  // Now managing two keys
  String? _generatedKeyV1;
  String? _generatedKeyV2;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _generateKeys();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Generate random 16-digit keys for V1 and V2
  void _generateKeys() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    
    String generate() => String.fromCharCodes(Iterable.generate(
        16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    
    setState(() {
      _generatedKeyV1 = "v1_${generate()}"; // Added prefix for clarity
      _generatedKeyV2 = "v2_${generate()}";
    });
  }

  Future<void> _createApi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      // 1. Create the document with BOTH keys
      await FirebaseFirestore.instance.collection('organizations').add({
        'name': _nameController.text.trim(),
        'apiKeyV1': _generatedKeyV1, // Legacy/V1 access
        'apiKeyV2': _generatedKeyV2, // Modern/V2 access
        'migrationStage': 'OLD',
        'isActive': true,
        'errorRate': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 2. Show Success Dialog
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
            Text('Organization Provisioned', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merchant keys successfully generated.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // V1 Key Display
            _buildDialogKeyRow("API Key V1 (Legacy)", _generatedKeyV1!),
            const SizedBox(height: 12),
            
            // V2 Key Display
            _buildDialogKeyRow("API Key V2 (Modern)", _generatedKeyV2!),

            const SizedBox(height: 12),
            const Text(
              '⚠️ Secure these keys immediately.',
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

  Widget _buildDialogKeyRow(String label, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: Colors.tealAccent
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              InkWell(
                child: const Icon(Icons.copy, color: Colors.grey, size: 18),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: key));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$label copied")),
                  );
                },
              ),
            ],
          ),
        ),
      ],
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

                const Text("Organization Name", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.tealAccent)),
                  ),
                ),
                const SizedBox(height: 24),

                // Keys Display Area
                const Text("Generated API Keys", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    children: [
                      _buildKeyDisplay("V1 Key (Legacy)", _generatedKeyV1),
                      const Divider(color: Colors.white12, height: 24),
                      _buildKeyDisplay("V2 Key (Modern)", _generatedKeyV2),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createApi,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isCreating
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Provision Organization", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyDisplay(String label, String? key) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                key ?? "Generating...",
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        if (key != null)
           IconButton(
             onPressed: _generateKeys,
             icon: const Icon(Icons.refresh, color: Colors.tealAccent, size: 18),
             tooltip: "Regenerate Keys",
           )
      ],
    );
  }
}