class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? command;
  final List<Map<String, dynamic>> commands;
  final bool shouldAnimate;
  final String? modelUsed;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.command,
    this.commands = const [],
    this.shouldAnimate = false,
    this.modelUsed,
  });

  List<Map<String, dynamic>> get allCommands {
    if (commands.isNotEmpty) return commands;
    if (command != null) return [command!];
    return const [];
  }
}
