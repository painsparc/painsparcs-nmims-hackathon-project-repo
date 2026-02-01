import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'agent_memory_service.dart'; // Import the new service

class MigrationScreen extends StatefulWidget {
  final String orgId;
  final String apiKeyV1; // Legacy Key
  final String apiKeyV2; // Modern Key (Target)
  final String orgName;

  const MigrationScreen({
    super.key,
    required this.orgId,
    required this.apiKeyV1,
    required this.apiKeyV2,
    required this.orgName,
  });

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> with TickerProviderStateMixin {
  // --- STATE VARIABLES ---
  
  // Operation Flags
  bool _isSeeding = false;
  bool _isMigrating = false;
  
  // Agent Logic State
  bool _isAgentThinking = false;
  Map<String, dynamic>? _agentResult;
  Color _agentPanelBorderColor = Colors.transparent;
  
  // Memory Service
  final AgentMemoryService _memoryService = AgentMemoryService();

  // Animation Controller
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Data Counters
  int _legacyCount = 0;
  int _migratedCount = 0;
  int _failedCount = 0;
  
  // Scrolling & Logs
  final List<ConsoleLogItem> _consoleLogs = [];
  final ScrollController _consoleScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchStats();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _consoleScrollController.dispose();
    super.dispose();
  }

  // --- LOGGING SYSTEM ---
  void _log(String message, {LogType type = LogType.info}) {
    if (!mounted) return;
    setState(() {
      _consoleLogs.add(ConsoleLogItem(message, type, DateTime.now()));
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScrollController.hasClients) {
        _consoleScrollController.animateTo(
          _consoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- DATA FETCHING ---
  Future<void> _fetchStats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('legacy_products')
          .where('apiKey', isEqualTo: widget.apiKeyV1)
          .count()
          .get();

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
    } catch (e) {
      debugPrint("Stats Fetch Error: $e");
    }
  }

  // ===========================================================================
  // 🚀 FEATURE 1: SEEDING LEGACY DATA
  // ===========================================================================
  Future<void> _seedLegacyData() async {
    setState(() => _isSeeding = true);
    _log("Initializing Legacy Seed (V1 Context)...", type: LogType.system);

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('legacy_products');

    // Clean up old data first
    final oldDocs = await collection.where('apiKey', isEqualTo: widget.apiKeyV1).get();
    for (var doc in oldDocs.docs) {
      batch.delete(doc.reference);
    }

    for (int i = 1; i <= 5; i++) {
      final docRef = collection.doc();
      batch.set(docRef, {
        'name': 'Legacy SKU-${1000 + i}',
        'price': (i * 150.0),
        'type': 'product',
        'apiKey': widget.apiKeyV1,
        'description': 'Standard inventory item imported from v1.',
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Inject Specific Errors for the Agent to "Remember"
    _createRiskyRecord(batch, collection, "Null Price Error", price: null); 
    _createRiskyRecord(batch, collection, "Negative Value Glitch", price: -500.0);

    await batch.commit();
    _log("Seed Complete: Data injected with known anomalies.", type: LogType.success);
    await _fetchStats();
    setState(() => _isSeeding = false);
  }

  void _createRiskyRecord(WriteBatch batch, CollectionReference col, String? name, {double? price}) {
    batch.set(col.doc(), {
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      'apiKey': widget.apiKeyV1,
      'type': 'product',
      'status': 'PENDING',
      'risk_flag': true,
    });
  }

  // ===========================================================================
  // 🧠 FEATURE 2: PREDICTIVE AI SCAN + MEMORY RECALL
  // ===========================================================================
  Future<void> _runPredictiveScan() async {
    setState(() {
      _isAgentThinking = true;
      _agentResult = null;
      _agentPanelBorderColor = Colors.tealAccent.withOpacity(0.5);
    });

    try {
      // 1. Scan the actual Legacy Data for patterns
      final riskyDocs = await FirebaseFirestore.instance
          .collection('legacy_products')
          .where('apiKey', isEqualTo: widget.apiKeyV1)
          .where('status', isEqualTo: 'PENDING')
          .get();

      bool hasNullPrice = false;
      bool hasNegativePrice = false;

      for (var doc in riskyDocs.docs) {
        final data = doc.data();
        if (data['price'] == null) hasNullPrice = true;
        if ((data['price'] is num) && data['price'] < 0) hasNegativePrice = true;
      }

      // 2. Consult the Memory Service
      Map<String, dynamic>? memoryFact;
      String errorContext = "STANDARD_MIGRATION";
      
      if (hasNullPrice) {
        errorContext = "NULL_VALUE";
        memoryFact = await _memoryService.recallPattern("NULL_VALUE", "price");
      } else if (hasNegativePrice) {
        errorContext = "NEGATIVE_VALUE";
        memoryFact = await _memoryService.recallPattern("NEGATIVE_VALUE", "price");
      }

      await Future.delayed(const Duration(seconds: 2)); // Simulate processing

      if (!mounted) return;

      // 3. Construct the "AI" Report
      String markdownReport;
      double confidence = memoryFact?['confidence'] ?? 0.0;
      int seenCount = memoryFact?['count'] ?? 0;
      bool isNew = memoryFact?['is_new'] ?? true;

      if (hasNullPrice || hasNegativePrice) {
        markdownReport = """
### ⚠️ Data Integrity Risk Detected

**Issue:** $errorContext detected in `legacy_products`.
**Impact:** Will cause Schema Validation failure in V2 API.

### 🧠 Memory & Adaptation
The agent has encountered this pattern **$seenCount times** previously.
Based on past resolutions, the recommended strategy is:
> *${memoryFact?['recommended_action']}*

**Strategic Decision:**
Agent will attempt **Auto-Remediation** during migration.
""";
      } else {
         markdownReport = """
### ✅ Green Light
Data structure matches V2 schema requirements.
**Confidence:** 99.8%
No historical anomalies detected for this dataset.
""";
         confidence = 0.99;
      }

      setState(() {
        _isAgentThinking = false;
        _agentResult = {
          'type': (hasNullPrice || hasNegativePrice) ? 'CRITICAL' : 'SAFE',
          'score': confidence,
          'ai_report': markdownReport,
          'memory_fact': memoryFact, // Store raw memory data for UI
        };
        _agentPanelBorderColor = (hasNullPrice || hasNegativePrice) ? Colors.orangeAccent : Colors.greenAccent;
      });

      if (isNew && (hasNullPrice || hasNegativePrice)) {
         _log("New pattern detected. Memory updated.", type: LogType.warning);
      } else if (hasNullPrice || hasNegativePrice) {
         _log("Pattern recognized from memory. Strategy adapted.", type: LogType.success);
      } else {
         _log("Scan Complete. Ready to migrate.", type: LogType.success);
      }

    } catch (e) {
      setState(() => _isAgentThinking = false);
      _log("Agent Failure: $e", type: LogType.error);
    }
  }

  // ===========================================================================
  // ⚡ FEATURE 3: EXECUTE MIGRATION (V1 -> V2)
  // ===========================================================================
  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _failedCount = 0;
      _agentResult = null; 
    });
    _log("--- MIGRATION SEQUENCE INITIATED ---", type: LogType.system);

    final legacySnapshot = await FirebaseFirestore.instance
        .collection('legacy_products')
        .where('apiKey', isEqualTo: widget.apiKeyV1)
        .where('status', isEqualTo: 'PENDING')
        .get();

    int success = 0;
    int fails = 0;

    for (var doc in legacySnapshot.docs) {
      final data = doc.data();
      
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        // --- AGENT AUTO-REMEDIATION (APPLYING MEMORY) ---
        dynamic price = data['price'];
        String name = data['name'] ?? "Unknown";

        // Fix Nulls
        if (price == null) {
          price = 0.0;
          _log("🤖 Agent Auto-Fix: Injected default price for '$name'", type: LogType.warning);
        }
        
        // Fix Negatives
        double finalPrice = double.tryParse(price.toString()) ?? 0.0;
        if (finalPrice < 0) {
          finalPrice = finalPrice.abs();
          _log("🤖 Agent Auto-Fix: Corrected negative sign for '$name'", type: LogType.warning);
        }

        if (name.toString().isEmpty) throw Exception("Critical: Name missing");

        // Write to V2
        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .collection('products')
            .add({
          'name': name,
          'price': finalPrice,
          'type': data['type'] ?? 'product',
          'migratedAt': FieldValue.serverTimestamp(),
          'legacyId': doc.id,
          'v2_schema_compliant': true,
          'origin_key': widget.apiKeyV1,
          'target_key_version': 'v2',
        });

        await doc.reference.update({'status': 'MIGRATED'});
        success++;

      } catch (e) {
        fails++;
        _log("Failed: $e", type: LogType.error);
        await doc.reference.update({'status': 'FAILED'});
      }
      
      if (mounted) setState(() => _failedCount = fails);
    }

    _log("--- SEQUENCE COMPLETE ---", type: LogType.system);
    _log("Result: $success Success / $fails Failed", type: LogType.info);
    
    await _fetchStats();
    if (mounted) setState(() => _isMigrating = false);
  }

  // ===========================================================================
  // 🎨 UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal, color: Colors.tealAccent, size: 20),
            const SizedBox(width: 10),
            Flexible( 
              child: Text("Migration Console: ${widget.orgName}", 
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF2C2C2E), height: 1),
        ),
      ),
      body: Column(
        children: [
          // 1. STATS HUD
          _buildStatsHeader(),

          // 1.5. API KEY DISPLAY
          _buildKeyDisplaySection(),

          // 2. EXPANDABLE WORKSPACE
          // FIX: Wrapped in LayoutBuilder to get REAL remaining space
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Determine heights dynamically based on available space
                final double availableHeight = constraints.maxHeight;
                // If Expanded (Agent Result exists), take 55% of space. If collapsed, fixed 80px.
                final double panelHeight = _agentResult != null ? (availableHeight * 0.55) : 80;

                return Column(
                  children: [
                    // A. AGENT PANEL
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      height: panelHeight,
                      width: double.infinity,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151517),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isAgentThinking ? Colors.tealAccent : _agentPanelBorderColor,
                          width: _agentResult != null ? 2 : 1
                        ),
                        boxShadow: _agentResult != null 
                          ? [BoxShadow(color: _agentPanelBorderColor.withOpacity(0.2), blurRadius: 30, spreadRadius: 1)]
                          : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildAgentContent()
                      ),
                    ),

                    // B. CONSOLE LOGS
                    // Takes whatever space is left
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1C1C1E),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.dvr, size: 14, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text("SYSTEM LOGS", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: _consoleScrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: _consoleLogs.length,
                                itemBuilder: (context, index) => _buildLogItem(_consoleLogs[index]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. CONTROL DECK
          _buildControlDeck(),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildKeyDisplaySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF111111),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "KEYS & CREDENTIALS",
            style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSingleKeyRow("V1 (Legacy)", widget.apiKeyV1, Colors.orangeAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildSingleKeyRow("V2 (Modern)", widget.apiKeyV2, Colors.tealAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleKeyRow(String label, String key, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF222224),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.white70),
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: key));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$label Key Copied"), duration: const Duration(milliseconds: 800)),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.copy, size: 14, color: Colors.grey),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAgentContent() {
    // If we have a result and it has memory data, extract it
    final memory = _agentResult?['memory_fact'] as Map<String, dynamic>?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 1. FIXED HEADER ROW ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.psychology, 
                      color: _agentResult != null ? Colors.white : Colors.grey),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text("AGENT REASONING CORE", 
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _agentResult != null ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.5,
                          fontSize: 12
                        )),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_isAgentThinking)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
              else if (_agentResult != null)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: _agentResult!['score'] > 0.8 ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: _agentResult!['score'] > 0.8 ? Colors.green : Colors.orange),
                   ),
                   child: Text(
                     "${(_agentResult!['score'] * 100).toInt()}% CONFIDENCE",
                     style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                   ),
                 )
              else
                 Text(
                   "STANDBY",
                   style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold),
                 )
            ],
          ),
        ),

        // --- 2. SCROLLABLE BODY ---
        if (_agentResult != null)
          Expanded(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Markdown(
                    shrinkWrap: true, // Allow it to live inside ListView
                    physics: const NeverScrollableScrollPhysics(), // Let the parent ListView handle scrolling
                    data: _agentResult!['ai_report'] ?? "",
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    styleSheet: MarkdownStyleSheet(
                      h3: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 18, height: 2),
                      h4: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.5),
                      p: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                      listBullet: const TextStyle(color: Colors.tealAccent),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      blockquote: TextStyle(color: Colors.orange[300], fontStyle: FontStyle.italic),
                      blockquoteDecoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border(left: BorderSide(color: Colors.orange.withOpacity(0.5), width: 3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      code: const TextStyle(backgroundColor: Colors.transparent, fontFamily: 'monospace', color: Colors.tealAccent),
                    ),
                  ),

                  // --- 🧠 VISUAL MEMORY BLOCK ---
                  if (memory != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history, size: 14, color: Colors.tealAccent),
                              SizedBox(width: 8),
                              Text("MEMORY & ADAPTATION ENGINE", style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMemoryStat("Pattern ID", memory['pattern_key'].toString().split('_').first),
                              _buildMemoryStat("Times Seen", "${memory['count']}x"),
                              _buildMemoryStat("Resolution", memory['last_outcome']),
                            ],
                          )
                        ],
                      ),
                    ),
                  
                  // Add some bottom padding for the list view
                  const SizedBox(height: 20),
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildMemoryStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildControlDeck() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSeeding || _isMigrating ? null : _seedLegacyData,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSeeding 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("1. SEED DATA", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ScaleTransition(
                  scale: _isSeeding || _isMigrating || _agentResult != null ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
                  child: OutlinedButton.icon(
                    onPressed: _isSeeding || _isMigrating || _isAgentThinking ? null : _runPredictiveScan,
                    icon: const Icon(Icons.radar),
                    label: const Text("2. PREDICTIVE SCAN", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      foregroundColor: Colors.tealAccent,
                      backgroundColor: Colors.teal.withOpacity(0.05),
                      side: const BorderSide(color: Colors.tealAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSeeding || _isMigrating ? null : _startMigration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 22),
                backgroundColor: Colors.tealAccent.shade700,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: Colors.tealAccent.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isMigrating
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch, size: 22),
                      SizedBox(width: 12),
                      Text("3. EXECUTE MIGRATION", 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem("Legacy DB", _legacyCount, Colors.grey),
          Icon(Icons.arrow_right_alt, color: Colors.grey[800], size: 30),
          _buildStatItem("Live API", _migratedCount, Colors.tealAccent),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildStatItem("Errors", _failedCount, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), 
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildLogItem(ConsoleLogItem item) {
    Color color;
    IconData icon;
    
    switch (item.type) {
      case LogType.error: color = Colors.redAccent; icon = Icons.error_outline; break;
      case LogType.success: color = Colors.greenAccent; icon = Icons.check_circle_outline; break;
      case LogType.warning: color = Colors.orangeAccent; icon = Icons.warning_amber; break;
      case LogType.system: color = Colors.tealAccent; icon = Icons.terminal; break;
      default: color = Colors.grey; icon = Icons.arrow_right;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 10, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.message, 
              style: TextStyle(fontFamily: 'Courier', color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// --- HELPER CLASSES ---
enum LogType { info, success, error, warning, system }

class ConsoleLogItem {
  final String message;
  final LogType type;
  final DateTime timestamp;
  ConsoleLogItem(this.message, this.type, this.timestamp);
}