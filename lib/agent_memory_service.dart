import 'package:cloud_firestore/cloud_firestore.dart';

class AgentMemoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// THE CORE LOGIC:
  /// 1. Checks if we've seen this error pattern before
  /// 2. Updates the "Neural Weights" (Confidence Score) based on frequency
  /// 3. Returns a structured memory object for the UI
  Future<Map<String, dynamic>> recallPattern(String errorType, String contextKey) async {
    // 1. GENERATE DETERMINISTIC KEY
    // e.g., "NULL_VALUE_price" or "NEGATIVE_VALUE_price"
    final String patternKey = "${errorType.toUpperCase()}_$contextKey";
    
    final docRef = _db.collection('agent_memory').doc(patternKey);
    final doc = await docRef.get();

    if (doc.exists) {
      // --- EXISTING MEMORY PATH ---
      final data = doc.data()!;
      int count = data['occurrence_count'] ?? 1;
      double confidence = data['confidence'] ?? 0.5;

      // HEURISTIC: "Practice makes perfect"
      // Every time we see it, confidence grows slightly, capped at 0.95
      double newConfidence = (confidence + 0.05).clamp(0.0, 0.95);

      // Update Memory asynchronously (don't block UI)
      docRef.update({
        'occurrence_count': count + 1,
        'confidence': newConfidence,
        'last_seen': FieldValue.serverTimestamp(),
      });

      return {
        'is_new': false,
        'count': count + 1,
        'confidence': newConfidence,
        'pattern_key': patternKey,
        'recommended_action': data['recommended_action'] ?? "Apply standard schema validation fix.",
        'last_outcome': data['last_outcome'] ?? "RESOLVED"
      };
    } else {
      // --- NEW MEMORY PATH ---
      // We are learning this for the first time
      await docRef.set({
        'pattern_key': patternKey,
        'first_seen': FieldValue.serverTimestamp(),
        'last_seen': FieldValue.serverTimestamp(),
        'occurrence_count': 1,
        'error_type': errorType,
        'context_key': contextKey,
        'recommended_action': _getHardcodedRecommendation(errorType), // Initial knowledge base
        'last_outcome': 'LEARNING',
        'confidence': 0.45, // Start with low confidence
      });

      return {
        'is_new': true,
        'count': 1,
        'confidence': 0.45,
        'pattern_key': patternKey,
        'recommended_action': "Analyze and patch schema.",
        'last_outcome': "PENDING"
      };
    }
  }

  // A tiny knowledge base to seed the first memory
  String _getHardcodedRecommendation(String errorType) {
    switch (errorType) {
      case 'NULL_VALUE': return "Inject default value or request manual override.";
      case 'NEGATIVE_VALUE': return "Apply ABS() transformation to correct sign.";
      case 'TYPE_MISMATCH': return "Cast variable to required type.";
      default: return "Manual intervention required.";
    }
  }
}