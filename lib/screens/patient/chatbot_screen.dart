import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_base_screen.dart';
import '../../widgets/patient_nav_bar.dart';
import 'home_screen.dart';

bool _isChatInitialized = false;

List<Map<String, dynamic>> _globalMessages = [];

ChatSession? _globalChatSession;

// CHATBOT AI SCREEN WITH INDOOR NAVIGATION MAPPING (GEMINI PRO FLOW)
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _chatController = TextEditingController();
  bool _isLoading = false;

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late final GenerativeModel _model;

  @override
  void initState() {
    super.initState();

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are Q-Health AI, a smart indoor navigation and service assistant for the Q-Health hospital app. "
        "Your goal is to help patients find shops, cafes, and amenities inside the hospital while they wait for their queue turn.\n\n"
        "Here is the official hospital layout map:\n"
        "- GROUND FLOOR: Main Lobby, Hospital Pharmacy, Cooperative Convenience Store, ZUS Coffee.\n"
        "- LEVEL 1: Screening Room, Bakery & Snack Kiosk, Fruit Shop.\n"
        "- LEVEL 2: Consultation Room (Doctor's Room), Main Cafeteria (Food Court).\n\n"
        "STRICT INTERACTION RULES:\n"
        "1. When a user asks to find a shop, cafe, food, or location, DO NOT give the directions immediately. You MUST first politely ask for their current location (e.g., 'May I know where you are right now so I can help guide you?').\n"
        "2. Once they tell you their current location, provide clear, step-by-step indoor walking directions to their destination, detailing the floors to navigate and specific hospital landmarks to pass by.\n"
        "3. Always maintain a professional, helpful, and welcoming tone. You MUST reply in the same language used by the patient (Malay or English).",
      ),
    );

    if (!_isChatInitialized) {
      _globalChatSession = _model.startChat();

      _globalMessages.add({
        'text':
            "Hello! I am your Q-Health AI Assistant. While waiting for your turn, feel free to ask me if you want to find a cafe, convenience store, or any nearby shops!",
        'isAI': true,
      });

      _isChatInitialized = true;
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _globalChatSession == null) return;

    setState(() {
      _globalMessages.add({'text': text, 'isAI': false});
      _isLoading = true;
    });
    _chatController.clear();

    try {
      final response = await _globalChatSession!.sendMessage(
        Content.text(text),
      );
      final aiText = response.text;

      if (aiText != null) {
        setState(() {
          _globalMessages.add({'text': aiText, 'isAI': true});
        });
      }
    } catch (e) {
      debugPrint("====================================");
      debugPrint("ERROR : $e");
      debugPrint("====================================");

      setState(() {
        _globalMessages.add({
          'text':
              'The system is experiencing a technical issue. Please check your internet connection or API Key settings.',
          'isAI': true,
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBaseScreen(
      bottomNavBar: buildGlassBottomNavBar(context, currentIndex: 4),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // TOP BAR SECTION (Kekal original)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.avatarBg,
                          border: Border.all(
                            color: Colors.pinkAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.pinkAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Online',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // MAIN MESSAGE LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    // LIST MESSAGE REFERRENCING GLOBAL VARIABLE
                    itemCount: _globalMessages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _globalMessages.length && _isLoading) {
                        return _buildLoadingBubble();
                      }
                      final msg = _globalMessages[index];
                      return _buildChatBubble(
                        text: msg['text'],
                        isAI: msg['isAI'],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 140),
              ],
            ),
          ),

          // PATIENT TEXT INPUT BOX
          Positioned(bottom: 90, left: 20, right: 20, child: _buildChatInput()),
        ],
      ),
    );
  }

  Widget _buildChatBubble({required String text, required bool isAI}) {
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAI
              ? AppTheme.glassBg
              : Colors.pinkAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 0 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 0),
          ),
          border: Border.all(
            color: isAI
                ? AppTheme.glassBorder
                : Colors.pinkAccent.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.glassBorder, width: 1),
        ),
        child: const SizedBox(
          width: 30,
          height: 15,
          child: CircularProgressIndicator(
            color: Colors.pinkAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Ask AI anything...",
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.pinkAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
