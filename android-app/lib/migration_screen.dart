import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'agent_brain.dart';

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

class _MigrationScreenState extends State<MigrationScreen> with TickerProviderStateMixin {
  // --- STATE VARIABLES ---
  
  // Operation Flags
  bool _isSeeding = false;
  bool _isMigrating = false;
  
  // Agent Logic State
  bool _isAgentThinking = false;
  Map<String, dynamic>? _agentResult;
  Color _agentPanelBorderColor = Colors.transparent;
  
  // Animation Controller for "Pulse" effect on Scan button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Data Counters
  int _legacyCount = 0;
  int _migratedCount = 0;
  int _failedCount = 0;
  
  // Scrolling & Logs
  final List<ConsoleLogItem> _consoleLogs = [];
  final ScrollController _consoleScrollController = ScrollController();
  final ScrollController _markdownScrollController = ScrollController(); // Added for Markdown

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
    _markdownScrollController.dispose(); // Dispose properly
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
          .where('apiKey', isEqualTo: widget.apiKey)
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
    _log("Initializing Legacy Data Seed protocol...", type: LogType.system);

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('legacy_products');

    for (int i = 1; i <= 5; i++) {
      final docRef = collection.doc();
      batch.set(docRef, {
        'name': 'Legacy SKU-${1000 + i}',
        'price': (i * 150.0),
        'type': 'product',
        'apiKey': widget.apiKey,
        'description': 'Standard inventory item imported from v1.',
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    _createRiskyRecord(batch, collection, "Null Price Error", price: null);
    _createRiskyRecord(batch, collection, "Negative Value Glitch", price: -500.0);
    _createRiskyRecord(batch, collection, null, price: 299.99);

    await batch.commit();
    _log("Seed Complete: 5 Valid Records, 3 Corrupted Records injected.", type: LogType.success);
    await _fetchStats();
    setState(() => _isSeeding = false);
  }

  void _createRiskyRecord(WriteBatch batch, CollectionReference col, String? name, {double? price}) {
    batch.set(col.doc(), {
      if (name != null) 'name': name,
      if (price != null) 'price': price,
      'apiKey': widget.apiKey,
      'type': 'product',
      'status': 'PENDING',
      'risk_flag': true,
    });
  }

  // ===========================================================================
  // 🧠 FEATURE 2: PREDICTIVE AI SCAN
  // ===========================================================================
  Future<void> _runPredictiveScan() async {
    setState(() {
      _isAgentThinking = true;
      _agentResult = null;
      _agentPanelBorderColor = Colors.tealAccent.withOpacity(0.5);
    });

    try {
      final agent = MigrationAgent(orgId: widget.orgId, apiKey: widget.apiKey);
      final result = await agent.predictMigrationRisks();

      if (!mounted) return;

      bool isCritical = result['type'] == 'CRITICAL';
      
      setState(() {
        _isAgentThinking = false;
        _agentResult = result;
        _agentPanelBorderColor = isCritical ? Colors.redAccent : Colors.greenAccent;
      });

      _log("AI Scan Completed. Risk Score: ${(result['score'] * 100).toInt()}%", 
        type: isCritical ? LogType.error : LogType.success);

    } catch (e) {
      setState(() => _isAgentThinking = false);
      _log("Agent Failure: $e", type: LogType.error);
    }
  }

  // ===========================================================================
  // ⚡ FEATURE 3: EXECUTE MIGRATION
  // ===========================================================================
  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _failedCount = 0;
      // ✅ FIX: Close the AI Panel so user sees the terminal
      _agentResult = null; 
    });
    _log("--- MIGRATION SEQUENCE INITIATED ---", type: LogType.system);

    final legacySnapshot = await FirebaseFirestore.instance
        .collection('legacy_products')
        .where('apiKey', isEqualTo: widget.apiKey)
        .where('status', isEqualTo: 'PENDING')
        .get();

    if (legacySnapshot.docs.isEmpty) {
      _log("Migration Aborted: No pending records found.", type: LogType.warning);
      setState(() => _isMigrating = false);
      return;
    }

    int success = 0;
    int fails = 0;

    for (var doc in legacySnapshot.docs) {
      final data = doc.data();
      final docId = doc.id;
      
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        if (data['name'] == null || data['name'].toString().isEmpty) {
          throw Exception("Schema Violation: 'name' field is missing");
        }
        if (data['price'] == null) {
           throw Exception("Schema Violation: 'price' field is null");
        }
        final price = double.tryParse(data['price'].toString()) ?? 0.0;
        if (price < 0) {
          throw Exception("Business Logic: Negative price detected ($price)");
        }

        await FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .collection('products')
            .add({
          'name': data['name'],
          'price': price,
          'type': data['type'] ?? 'product',
          'migratedAt': FieldValue.serverTimestamp(),
          'legacyId': docId,
          'v2_schema_compliant': true,
        });

        await doc.reference.update({'status': 'MIGRATED'});
        _log("Migrated: ${data['name']}", type: LogType.success);
        success++;

      } catch (e) {
        fails++;
        _log("Failed: $e", type: LogType.error);
        await doc.reference.update({'status': 'FAILED'});
        await FirebaseFirestore.instance.collection('system_error_logs').add({
          'apiKey': widget.apiKey,
          'errorType': 'MIGRATION_FAILURE',
          'message': e.toString(),
          'timestamp': FieldValue.serverTimestamp(),
          'resolved': false,
        });
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
    final screenHeight = MediaQuery.of(context).size.height;
    // Calculate panel height safely
    final double agentPanelHeight = _agentResult != null ? screenHeight * 0.55 : 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.terminal, color: Colors.tealAccent, size: 20),
            const SizedBox(width: 10),
            Flexible( // ✅ FIX: Prevents title overflow
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

          // 2. EXPANDABLE WORKSPACE
          Expanded(
            child: Column(
              children: [
                // A. AGENT PANEL
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  height: agentPanelHeight,
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
                  child: _buildAgentContent(),
                ),

                // B. CONSOLE LOGS
                Expanded( // ✅ FIX: Consumes remaining space
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
            ),
          ),

          // 3. CONTROL DECK
          _buildControlDeck(),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildAgentContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE (Title)
              Expanded( // ✅ FIX: Prevents text overflow on left
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

              // RIGHT SIDE (Status)
              const SizedBox(width: 8),
              if (_isAgentThinking)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
              else if (_agentResult != null)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: _agentResult!['score'] > 0.8 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                     borderRadius: BorderRadius.circular(4),
                     border: Border.all(color: _agentResult!['score'] > 0.8 ? Colors.green : Colors.red),
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

        // Body (Only Render if Expanded)
        if (_agentResult != null)
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Scrollbar(
                  controller: _markdownScrollController, // ✅ FIX: Bind controller
                  thumbVisibility: true,
                  radius: const Radius.circular(4),
                  child: Markdown(
                    controller: _markdownScrollController, // ✅ FIX: Bind same controller
                    data: _agentResult!['ai_report'] ?? "",
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                ),
              ),
            ),
          )
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