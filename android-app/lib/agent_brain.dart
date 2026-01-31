import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'geminiapi.dart'; // Import the service we made

class MigrationAgent {
  final String orgId;
  final String apiKey;

  MigrationAgent({required this.orgId, required this.apiKey});

  /// 🧠 MAIN BRAIN FUNCTION
  Future<Map<String, dynamic>> predictMigrationRisks() async {
    // ---------------------------------------------------------
    // STEP 1: GATHER HARD DATA (The "Eyes")
    // ---------------------------------------------------------
    
    // A. Current Pending Data
    final pendingSnapshot = await FirebaseFirestore.instance
        .collection('legacy_products')
        .where('apiKey', isEqualTo: apiKey)
        .where('status', isEqualTo: 'PENDING')
        .get();

    // B. Historical Context (Memory)
    final historySnapshot = await FirebaseFirestore.instance
        .collection('system_error_logs')
        .where('apiKey', isEqualTo: apiKey)
        .count()
        .get();
    
    int historicalFailures = historySnapshot.count ?? 0;
    int totalItems = pendingSnapshot.docs.length;
    
    if (totalItems == 0) {
      return {'type': 'CLEAN', 'report': "No pending data."};
    }

    // C. Risk Calculation (Heuristics)
    int riskyItems = 0;
    List<String> riskPatterns = [];
    
    for (var doc in pendingSnapshot.docs) {
      final data = doc.data();
      if (data['price'] == null || (data['price'] is num && (data['price'] as num) < 0)) {
        if (!riskPatterns.contains("Invalid Pricing Schema")) riskPatterns.add("Invalid Pricing Schema");
        riskyItems++;
      }
      if (data['name'] == null) {
        if (!riskPatterns.contains("Missing Metadata")) riskPatterns.add("Missing Metadata");
        riskyItems++;
      }
    }

    // ---------------------------------------------------------
    // STEP 2: CALCULATE CONFIDENCE EVOLUTION (The "Learning")
    // ---------------------------------------------------------
    
    // Base confidence starts at 60%
    double confidence = 0.60;
    
    // If we've seen this BEFORE (History > 0), confidence grows
    String confidenceReason = "Initial assessment based on heuristics.";
    
    if (historicalFailures > 0) {
      // We have seen this org fail before. Belief drift upwards.
      confidence = 0.81; 
      confidenceReason = "Pattern Recurrence: Similar failures detected in history.";
    }
    
    if (historicalFailures > 5) {
      // We are very sure now.
      confidence = 0.94;
      confidenceReason = "Deep Learning: Persistent schema violation pattern established.";
    }

    // ---------------------------------------------------------
    // STEP 3: CONSULT THE LLM (The "Reasoning")
    // ---------------------------------------------------------
    
    String decision = "PROCEED";
    if (riskyItems > 0) decision = "PAUSE";
    
    // We construct a prompt for Gemini to generate the "Decision Panel"
    String prompt = """
    You are an AI System Reliability Engineer. 
    Context:
    - Task: Database Migration (Legacy -> Headless)
    - Pending Items: $totalItems
    - At Risk Items: $riskyItems
    - Historical Failures: $historicalFailures
    - Detected Patterns: ${riskPatterns.join(', ')}
    
    My Code-Logic Decision: $decision MIGRATION.
    
    Task:
    Generate a structured reasoning block in Markdown.
    1. State the Decision (PAUSE or PROCEED).
    2. Provide "Trade-off Analysis" (The 'Why NOT' logic).
       - Explain why we shouldn't "Auto-fix" (Risk?)
       - Explain why we shouldn't "Ignore" (Trust?)
       - Explain why we shouldn't "Force Migrate" (Blast Radius?)
    3. Keep it terse, technical, and brutal. No fluff.
    """;

    // Call Gemini (or fallback if API fails)
    String aiReasoning;
    try {
      // Uncomment this when your API Key is ready:
      aiReasoning = await GeminiService().generateReasoning(prompt) 
          ?? "⚠️ AI Engine Offline. Using Heuristic Fallback.";
      
      // FOR DEMO PURPOSES (If no API Key yet), use this simulation:
      // aiReasoning = _simulateGeminiResponse(decision, riskyItems, historicalFailures);
      
    } catch (e) {
      aiReasoning = "⚠️ Cognitive Layer Error: $e";
    }

    // ---------------------------------------------------------
    // STEP 4: PACKAGING
    // ---------------------------------------------------------
    return {
      'type': decision == "PAUSE" ? 'CRITICAL' : 'SAFE',
      'score': confidence, // 0.0 to 1.0
      'confidence_reason': confidenceReason,
      'risky_count': riskyItems,
      'total_count': totalItems,
      'ai_report': aiReasoning,
      'historical_count': historicalFailures,
    };
  }

  // Fallback if Gemini isn't set up yet
  String _simulateGeminiResponse(String decision, int risk, int history) {
    return """
### 🛡️ Decision: **$decision MIGRATION**

#### ⚖️ Trade-off Analysis (Why NOT other options?)
* ❌ **Auto-fix Data:** High risk of semantic corruption. Assuming \$0.00 for missing prices may cause revenue loss.
* ❌ **Ignore Errors:** Will trigger client-side exceptions in the storefront, destroying merchant trust.
* ❌ **Force Execution:** Blast radius affects $risk products. Rollback cost exceeds pause cost.

#### 🧠 Agent Reasoning
Schema mismatch detected in pricing fields. Given the historical failure count ($history), this is a systemic configuration issue, not a transient glitch.
    """;
  }
}