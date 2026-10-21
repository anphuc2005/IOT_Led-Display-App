import 'package:equatable/equatable.dart';

enum ChatMessageStatus { sending, sent, failed }

class ChatMessage extends Equatable {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? command;
  final ChatMessageStatus status;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.command,
    this.status = ChatMessageStatus.sent,
  });

  @override
  List<Object?> get props => [id, content, isUser, timestamp, command, status];
}
