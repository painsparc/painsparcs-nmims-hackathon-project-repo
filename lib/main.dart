import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'createapi.dart';
import 'migration_screen.dart';
import 'merchant_storefront.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MigrationAgentApp());
}

class MigrationAgentApp extends StatelessWidget {
  const MigrationAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Migration Sim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

// --- 1. THE SPLIT SCREEN ENTRY POINT ---
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // LEFT: Merchant (Storefront)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MerchantStorefront()),
                );
              },
              child: Container(
                color: const Color(0xFFF5F5F7), // Light Theme
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront, size: 80, color: Colors.grey[800]),
                    const SizedBox(height: 20),
                    Text(
                      "I am a Merchant",
                      style: TextStyle(
                        color: Colors.grey[900],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "View my live storefront",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // RIGHT: Provider (Admin Console)
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardScreen()),
                );
              },
              child: Container(
                color: const Color(0xFF1E1E1E), // Dark Theme
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.terminal, size: 80, color: Colors.tealAccent),
                    const SizedBox(height: 20),
                    const Text(
                      "I am the API Provider",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Manage keys & migration agents",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. THE ADMIN DASHBOARD (Provider View) ---
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Admin Console'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2C2C2C),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateApiScreen()),
          );
        },
        icon: const Icon(Icons.add_circle_outline),
        label: const Text("New API Key"),
        backgroundColor: Colors.tealAccent.shade700,
        foregroundColor: Colors.white,
      ),
      body: const ApiKeyList(),
    );
  }
}

class ApiKeyList extends StatelessWidget {
  const ApiKeyList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No Organizations", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String orgName = data['name'] ?? 'Unknown Org';
            final String apiKey = data['apiKey'] ?? 'No Key';
            final String id = docs[index].id;

            return Card(
              color: const Color(0xFF2C2C2C),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  orgName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Key: $apiKey',
                    style: const TextStyle(fontFamily: 'Courier', color: Colors.grey, fontSize: 12),
                  ),
                ),
                onTap: () {
                  // Navigate to Migration/Agent Console
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MigrationScreen(
                        orgId: id,
                        apiKey: apiKey,
                        orgName: orgName,
                      ),
                    ),
                  );
                },
                // ✅ RESTORED: Copy & Delete Buttons
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // COPY BUTTON
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: Colors.tealAccent),
                      tooltip: 'Copy API Key',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: apiKey));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("API Key Copied to Clipboard"),
                            duration: Duration(seconds: 1),
                            backgroundColor: Colors.teal,
                          ),
                        );
                      },
                    ),
                    // DELETE BUTTON
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                      tooltip: 'Delete Organization',
                      onPressed: () {
                        _confirmDelete(context, id, orgName);
                      },
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

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Delete Organization?", style: TextStyle(color: Colors.white)),
        content: Text("This will permanently remove '$name' and all its data.", 
          style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('organizations').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}