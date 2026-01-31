import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Required for Agent output
import 'agent_brain.dart'; // The brain we just built

class MigrationScreen extends StatefulWidget {
  final String orgId;
  final String apiKey;
  final String orgName;

  const MigrationScreen({
    super.key,
    required this.orgId,
    required this.apiKey,
    required this.orgName,
  });

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _isSeeding = false;
  bool _isMigrating = false;
  
  // Agent State
  bool _isAgentThinking = false;
  String? _agentReport;
  
  // Stats
  int _legacyCount = 0;
  int _migratedCount = 0;
  int _failedCount = 0;
  
  // Real-time logs for the UI
  final List<String> _consoleLogs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  void _log(String message) {
    setState(() {
      _consoleLogs.add("> $message");
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchStats() async {
    // Count legacy items for this API Key
    final snapshot = await FirebaseFirestore.instance
        .collection('legacy_products')
        .where('apiKey', isEqualTo: widget.apiKey)
        .count()
        .get();

    // Count live items inside the specific Organization
    final liveSnapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.orgId)
        .collection('products')
        .count()
        .get();

    if (mounted) {
      setState(() {
        _legacyCount = snapshot.count ?? 0;
        _migratedCount = liveSnapshot.count ?? 0;
      });
    }
  }

  // 1. GENERATE "OLD" DATA (Some valid, some broken)
  Future<void> _seedLegacyData() async {
    setState(() => _isSeeding = true);
    _log("Initializing Legacy Data Seed for ${widget.orgName}...");

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('legacy_products');

    // Valid Products
    final validItems = [
      {'name': 'Premium Leather Jacket', 'price': 12000.0, 'type': 'product'},
      {'name': 'Consultation Hour', 'price': 1500.0, 'type': 'service'},
      {'name': 'Wireless Headphones', 'price': 3400.0, 'type': 'product'},
      {'name': 'Annual Subscription', 'price': 999.0, 'type': 'service'},
      {'name': 'Gaming Mouse', 'price': 2500.0, 'type': 'product'},
    ];

    for (var item in validItems) {
      final docRef = collection.doc();
      batch.set(docRef, {
        ...item,
        'apiKey': widget.apiKey, // Old system used this to identify ownership
        'description': 'Imported from legacy system.',
        'imageUrl': 'https://via.placeholder.com/150',
        'requiresSize': false,
        'status': 'PENDING', // Migration status
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ⚠️ BROKEN DATA (For the Agent to find)
    // 1. Missing Price (Corrupted Schema)
    final docRef1 = collection.doc();
    batch.set(docRef1, {
      'name': 'Corrupted Item #884',
      // 'price': MISSING
      'type': 'product',
      'apiKey': widget.apiKey,
      'status': 'PENDING',
      'imageUrl': '', 
    });

    // 2. Negative Price (Logic Error)
    final docRef2 = collection.doc();
    batch.set(docRef2, {
      'name': 'Refund Glitch Item',
      'price': -500.0, 
      'type': 'product',
      'apiKey': widget.apiKey,
      'status': 'PENDING',
    });

    // 3. Missing Name (Data Integrity)
    final docRef3 = collection.doc();
    batch.set(docRef3, {
      'price': 100.0,
      'type': 'product',
      'apiKey': widget.apiKey,
      'status': 'PENDING',
    });

    await batch.commit();
    _log("Seeding complete. Added 5 valid items and 3 corrupted items.");
    await _fetchStats();
    setState(() => _isSeeding = false);
  }

  // 2. THE MIGRATION PROCESS
  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _failedCount = 0;
      _agentReport = null; // Reset agent report on new run
    });
    _log("STARTING MIGRATION PROCESS...");
    _log("Target: Headless API Structure (organizations/${widget.orgId}/products)");

    // Get all pending legacy products
    final legacySnapshot = await FirebaseFirestore.instance
        .collection('legacy_products')
        .where('apiKey', isEqualTo: widget.apiKey)
        .where('status', isEqualTo: 'PENDING')
        .get();

    if (legacySnapshot.docs.isEmpty) {
      _log("No pending legacy data found.");
      setState(() => _isMigrating = false);
      return;
    }

    int success = 0;
    int fails = 0;

    for (var doc in legacySnapshot.docs) {
      final data = doc.data();
      final docId = doc.id;
      
      _log("Processing ${docId.substring(0, 6)}...");
      await Future.delayed(const Duration(milliseconds: 300)); // Fake latency for visual effect

      try {
        // --- VALIDATION LOGIC (Simulating the API Backend) ---
        
        // Check 1: Name exists
        if (data['name'] == null || data['name'].toString().isEmpty) {
          throw Exception("Validation Error: Product Name is missing.");
        }

        // Check 2: Price exists and is positive
        if (data['price'] == null) {
           throw Exception("Validation Error: Price field is null.");
        }
        final price = double.tryParse(data['price'].toString()) ?? 0.0;
        if (price < 0) {
          throw Exception("Logic Error: Price cannot be negative ($price).");
        }

        // --- MIGRATION WRITE ---
        // Write to the LIVE Organization collection
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .collection('products')
            .add({
          'name': data['name'],
          'price': price,
          'type': data['type'] ?? 'product',
          'description': data['description'] ?? 'Migrated Item',
          'imageUrl': data['imageUrl'] ?? '',
          'requiresSize': data['requiresSize'] ?? false,
          'migratedAt': FieldValue.serverTimestamp(),
          'legacyId': docId,
        });

        // Mark legacy as DONE
        await doc.reference.update({'status': 'MIGRATED'});
        _log("✓ Success: ${data['name']}");
        success++;

      } catch (e) {
        // --- FAILURE HANDLING ---
        fails++;
        _log("✗ FAILED: $e");

        // Mark legacy as FAILED
        await doc.reference.update({'status': 'FAILED'});

        // ⚠️ LOG ERROR FOR THE AGENT TO SEE ⚠️
        await FirebaseFirestore.instance.collection('system_error_logs').add({
          'apiKey': widget.apiKey,
          'organizationId': widget.orgId,
          'errorType': 'MIGRATION_FAILURE',
          'message': e.toString(),
          'rawPayload': data.toString(),
          'timestamp': FieldValue.serverTimestamp(),
          'severity': 'HIGH',
          'resolved': false, // Agent needs to fix this
        });
      }
      
      // Update UI counts live
      if (mounted) {
        setState(() {
          _failedCount = fails;
        });
      }
    }

    _log("--------------------------------");
    _log("MIGRATION COMPLETE.");
    _log("Successful: $success");
    _log("Failed: $fails (Errors logged to System)");
    
    await _fetchStats();
    if (mounted) setState(() => _isMigrating = false);
  }

  // 3. THE AGENT BRAIN TRIGGER
  Future<void> _askAgent() async {
    setState(() {
      _isAgentThinking = true;
      _agentReport = null;
    });

    // Initialize the Brain (from agent_brain.dart)
    final agent = MigrationAgent(orgId: widget.orgId, apiKey: widget.apiKey);
    
    // Get the reasoning
    final result = await agent.analyzeFailures();

    if (mounted) {
      setState(() {
        _isAgentThinking = false;
        _agentReport = result;
      });
      // Scroll to top of report roughly (UI fix)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text("Migration: ${widget.orgName}"),
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          )
        ],
      ),
      body: Column(
        children: [
          // A. STATS HEADER
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Legacy DB", _legacyCount.toString(), Colors.grey),
                const Icon(Icons.arrow_forward, color: Colors.blueGrey),
                _buildStat("Live API", _migratedCount.toString(), Colors.greenAccent),
                _buildStat("Failures", _failedCount.toString(), Colors.redAccent),
              ],
            ),
          ),

          // B. AGENT INTELLIGENCE PANEL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF252526), // Lighter "Console" background
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology, color: Colors.tealAccent),
                        SizedBox(width: 8),
                        Text("AGENT DIAGNOSTICS", 
                          style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                    if (_isAgentThinking)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                    else
                      TextButton.icon(
                        onPressed: _askAgent,
                        icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                        label: const Text("ANALYZE LOGS", style: TextStyle(color: Colors.white)),
                        style: TextButton.styleFrom(backgroundColor: Colors.tealAccent.withOpacity(0.2)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Agent Output Area
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _agentReport != null ? 180 : 40, // Expand when report exists
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                  ),
                  child: _agentReport != null 
                    ? Scrollbar(
                        child: Markdown(
                          data: _agentReport!,
                          padding: EdgeInsets.zero,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Roboto'),
                            h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            h4: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            listBullet: const TextStyle(color: Colors.tealAccent),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          "Waiting for failure logs...",
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ),
                ),
              ],
            ),
          ),

          // C. CONSOLE LOG
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _consoleLogs.length,
                itemBuilder: (context, index) {
                  final log = _consoleLogs[index];
                  Color color = Colors.greenAccent;
                  if (log.contains("FAILED") || log.contains("Error") || log.contains("✗")) color = Colors.redAccent;
                  if (log.contains(">") || log.contains("Processing")) color = Colors.grey;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(fontFamily: 'Courier', color: color, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),

          // D. ACTION BUTTONS
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1C1C1E),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSeeding || _isMigrating ? null : _seedLegacyData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSeeding 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("1. Seed Data"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSeeding || _isMigrating ? null : _startMigration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isMigrating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("2. Run Migration"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}