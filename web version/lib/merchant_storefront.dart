import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MerchantStorefront extends StatefulWidget {
  const MerchantStorefront({super.key});

  @override
  State<MerchantStorefront> createState() => _MerchantStorefrontState();
}

class _MerchantStorefrontState extends State<MerchantStorefront> {
  // Simulating the "Config" file of the headless frontend
  String? _connectedOrgId;
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;

  // Simulate "Connecting" to the Headless Backend
  Future<void> _connectStore() async {
    setState(() => _isLoading = true);
    final key = _apiKeyController.text.trim();

    // Find the Org ID associated with this key
    final snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .where('apiKey', isEqualTo: key)
        .limit(1)
        .get();

    setState(() => _isLoading = false);

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _connectedOrgId = snapshot.docs.first.id;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid API Key. Connection Refused.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not connected, show the "Setup Screen"
    if (_connectedOrgId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.black),
                const SizedBox(height: 24),
                const Text(
                  "Store Setup",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Connect your Headless Backend to start selling.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(
                    labelText: "Enter API Key",
                    border: OutlineInputBorder(),
                    hintText: "sk_live_...",
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _connectStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Connect Store"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // IF CONNECTED: SHOW THE SHOE STORE
    return Scaffold(
      backgroundColor: Colors.white, // Clean E-commerce White
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("NIKE (Demo)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => setState(() => _connectedOrgId = null),
          )
        ],
      ),
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            height: 150,
            color: Colors.grey[200],
            child: const Center(
              child: Text(
                "NEW ARRIVALS",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black26),
              ),
            ),
          ),
          
          // Product Grid (Live from Firestore)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(_connectedOrgId)
                  .collection('products') // LISTENING TO LIVE MIGRATION
                  .orderBy('migratedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("Store Empty", style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text(
                          "Waiting for migration...",
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Placeholder
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(Icons.image, color: Colors.grey[300], size: 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['name'] ?? "Unknown Product",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "\$${data['price']?.toString() ?? '0.00'}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}