import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../service/chat_service.dart';
import '../components/chat_bubble.dart';

class ChatPage extends StatefulWidget {
  final String? initialQuestion;

  const ChatPage({
    Key? key,
    this.initialQuestion,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController _scrollController;
  late ChatService _chatService;
  bool _isLoading = false;
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _chatService = ChatService();
    _initializeSession();
    
    if (widget.initialQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askQuestion(widget.initialQuestion!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cleanupSession();
    super.dispose();
  }

  void _initializeSession() {
    if (_chatService.sessionId.isEmpty) {
      _chatService.setSessionId(const Uuid().v4());
    }
  }

  Future<void> _cleanupSession() async {
    await _chatService.cleanupSession();
  }

  void _askQuestion(String question) async {
    if (question.isEmpty) return;

    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().toString(),
      text: question,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    setState(() {
      _isLoading = true;
    });

    try {
      // Get AI response
      final answer = await _chatService.askQuestion(question);

      // Add AI response
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(aiMessage);
      });
      _scrollToBottom();
    } catch (e) {
      // Add error message
      final errorMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: 'Sorry, I could not process your question: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(errorMessage);
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Skincare Assistant'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ask me anything about skincare!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'I\'ll give personalized advice based on your analysis.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
          ),
          ChatInputField(
            onSubmit: _askQuestion,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
