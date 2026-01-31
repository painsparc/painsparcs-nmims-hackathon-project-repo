import 'dart:developer';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // ⚠️ SECURITY NOTE: In a real production app, restrict this key in Google Cloud Console
  // or proxy it through a backend. For this hackathon/demo, hardcoding is acceptable.
  static const String _apiKey = "AIzaSyAGanGVsin9mTm5yN2YUOO1lpz1VVq4Cok"; 
  
  late final GenerativeModel _model;

  // Singleton pattern to ensure we only initialize the model once
  static final GeminiService _instance = GeminiService._internal();

  factory GeminiService() {
    return _instance;
  }

  GeminiService._internal() {
    // Initialize the model (Gemini Pro is best for text-based logic/reasoning)
    _model = GenerativeModel(
      model: 'gemini-flash-latest', 
      apiKey: _apiKey,
      // Safety settings to prevent the agent from refusing safe queries
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  /// The main function to send a prompt to Gemini and get a text response.
  /// Returns [null] if the request fails.
  Future<String?> generateReasoning(String prompt) async {
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        log("Gemini returned empty response.");
        return null;
      }

      return response.text;
    } catch (e) {
      log("❌ Gemini API Error: $e");
      return "Agent Error: Unable to connect to cognitive reasoning layer. ($e)";
    }
  }

  /// Optional: Use this if you need to maintain a chat history (Context aware)
  ChatSession startChat() {
    return _model.startChat();
  }
}