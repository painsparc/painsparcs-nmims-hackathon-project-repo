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

  // Curated list of "Outline" style icons for the storefront
  final List<IconData> _storeIcons = [
    Icons.checkroom_outlined,
    Icons.shopping_bag_outlined,
    Icons.do_not_step_outlined, // Looks like a shoe
    Icons.hiking_outlined,      // Boot vibe
    Icons.roller_skating_outlined,
    Icons.ice_skating_outlined,
    Icons.directions_run_outlined,
    Icons.sports_tennis_outlined,
    Icons.watch_outlined,
    Icons.backpack_outlined,
  ];

  // Colors to make the icon backgrounds pop slightly
  final List<Color> _iconBgColors = [
    const Color(0xFFF5F5F7), // Grey
    const Color(0xFFE3F2FD), // Blue tint
    const Color(0xFFE0F2F1), // Teal tint
    const Color(0xFFFFF3E0), // Orange tint
    const Color(0xFFF3E5F5), // Purple tint
  ];

  // Simulate "Connecting" to the Headless Backend
  Future<void> _connectStore() async {
    setState(() => _isLoading = true);
    final key = _apiKeyController.text.trim();

    try {
      // 1. First, check if this is a valid V2 (Modern) Key
      final v2Snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .where('apiKeyV2', isEqualTo: key)
          .limit(1)
          .get();

      if (v2Snapshot.docs.isNotEmpty) {
        // SUCCESS: V2 Key found
        setState(() {
          _connectedOrgId = v2Snapshot.docs.first.id;
          _isLoading = false;
        });
        return;
      }

      // 2. If not V2, check if it is a V1 (Legacy) Key
      // We check both 'apiKeyV1' and the old 'apiKey' field for compatibility
      final v1Snapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .where('apiKeyV1', isEqualTo: key)
          .limit(1)
          .get();

      // Fallback check for old schema just in case
      final legacySnapshot = await FirebaseFirestore.instance
          .collection('organizations')
          .where('apiKey', isEqualTo: key)
          .limit(1)
          .get();

      setState(() => _isLoading = false);

      if (v1Snapshot.docs.isNotEmpty || legacySnapshot.docs.isNotEmpty) {
        // ERROR: User is trying to use a V1 Key
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Legacy V1 Key detected. Please upgrade to the V2 API Key."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        // ERROR: Key exists nowhere
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid API Key. Connection Refused."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------------------
    // STATE 1: SETUP SCREEN (Not Connected)
    // ----------------------------------------------------------------
    if (_connectedOrgId == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: "Back to Role Selection",
          ),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_outlined, size: 64, color: Colors.black87),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Store Setup",
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w800, 
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Paste your Organization API Key to connect the headless backend to this frontend.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: "API Key",
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.grey),
                    hintText: "v2_...",
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _connectStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Connect Store", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ----------------------------------------------------------------
    // STATE 2: LIVE STOREFRONT (Connected)
    // ----------------------------------------------------------------
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "NIKE", 
          style: TextStyle(
            color: Colors.black, 
            fontWeight: FontWeight.w900, 
            fontSize: 24,
            letterSpacing: 2.0,
            fontStyle: FontStyle.italic,
          )
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "Disconnect API",
            onPressed: () => setState(() => _connectedOrgId = null),
          )
        ],
      ),
      body: Column(
        children: [
          // Minimalist Banner
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "NEW COLLECTION",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "SUMMER 2026",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
          
          // Product Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('organizations')
                  .doc(_connectedOrgId)
                  .collection('products')
                  .orderBy('migratedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checkroom, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("Store is Empty", style: TextStyle(color: Colors.grey, fontSize: 18)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Waiting for Agent Migration...",
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // RESPONSIVE LAYOUT CONTAINER
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200), // Fixes huge desktop items
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300, // Intelligent responsiveness
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        
                        // Deterministic random icon assignment based on product name
                        final String name = data['name'] ?? "Unknown";
                        final int iconIndex = name.hashCode.abs() % _storeIcons.length;
                        final int colorIndex = name.hashCode.abs() % _iconBgColors.length;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image/Icon Area
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _iconBgColors[colorIndex],
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Icon(
                                          _storeIcons[iconIndex],
                                          size: 64,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Product Info
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['name'] ?? "Product",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Sustainable Series", // Dummy subtitle
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "\$${data['price']?.toString() ?? '0.00'}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const Icon(Icons.add_circle_outline, color: Colors.black),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}