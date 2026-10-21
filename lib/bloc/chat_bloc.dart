import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import 'led_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

final class ChatDraftChanged extends ChatEvent {
  final String value;
  const ChatDraftChanged(this.value);
  @override
  List<Object> get props => [value];
}

final class ChatMessageSubmitted extends ChatEvent {
  final String? value;
  const ChatMessageSubmitted([this.value]);
  @override
  List<Object?> get props => [value];
}

class ChatState extends Equatable {
  final List<ChatMessage> messages;
  final String draft;
  final bool isSending;
  final int inputRevision;

  const ChatState(
      {this.messages = const [],
      this.draft = '',
      this.isSending = false,
      this.inputRevision = 0});

  ChatState copyWith(
          {List<ChatMessage>? messages,
          String? draft,
          bool? isSending,
          int? inputRevision}) =>
      ChatState(
        messages: messages ?? this.messages,
        draft: draft ?? this.draft,
        isSending: isSending ?? this.isSending,
        inputRevision: inputRevision ?? this.inputRevision,
      );

  @override
  List<Object> get props => [messages, draft, isSending, inputRevision];
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AiService aiService;
  final LedBloc ledBloc;
  final Uuid _uuid;

  ChatBloc(
      {required this.aiService,
      required this.ledBloc,
      Uuid uuid = const Uuid()})
      : _uuid = uuid,
        super(ChatState(messages: [
          ChatMessage(
            id: uuid.v4(),
            content:
                'Xin chào! Mình có thể bật đèn, đổi màu, chỉnh độ sáng hoặc chọn hiệu ứng cho bạn.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ])) {
    on<ChatDraftChanged>(
        (event, emit) => emit(state.copyWith(draft: event.value)));
    on<ChatMessageSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
      ChatMessageSubmitted event, Emitter<ChatState> emit) async {
    if (state.isSending) return;
    final value = (event.value ?? state.draft).trim();
    if (value.isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      content: value,
      isUser: true,
      timestamp: DateTime.now(),
    );
    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      draft: '',
      isSending: true,
      inputRevision: state.inputRevision + 1,
    ));

    final result = await aiService.processCommand(value);
    final command = result['command'] as Map<String, dynamic>?;
    if (command != null) ledBloc.add(LedCommandRequested(command));
    final assistantMessage = ChatMessage(
      id: _uuid.v4(),
      content: result['response'] as String,
      isUser: false,
      timestamp: DateTime.now(),
      command: command,
    );
    emit(state.copyWith(
        messages: [...state.messages, assistantMessage], isSending: false));
  }
}
