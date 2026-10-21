import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/app_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../models/chat_message.dart';
import '../widgets/app_widgets.dart';
import 'settings_screen.dart';

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  static const _suggestions = [
    'Bật đèn màu xanh dương',
    'Giảm độ sáng xuống 30%',
    'Bật hiệu ứng cầu vồng',
    'Bật chế độ tự động',
  ];

  @override
  Widget build(BuildContext context) {
    final hasApiKey =
        context.select<AppBloc, bool>((bloc) => bloc.state.apiKey.isNotEmpty);
    return SafeArea(
      child: Column(children: [
        ResponsiveContent(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: const ScreenHeader(
              title: 'Trợ lý AI',
              subtitle: 'Điều khiển đèn bằng câu lệnh tự nhiên'),
        ),
        if (!hasApiKey)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatusBanner(
              icon: Icons.key_off_rounded,
              title: 'Chưa có Gemini API Key',
              message: 'Thêm API key trong Cài đặt để bắt đầu trò chuyện.',
              color: Theme.of(context).colorScheme.error,
              action: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: const Text('Cài đặt'),
              ),
            ),
          ),
        Expanded(
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) => ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              itemCount: state.messages.length + (state.isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (state.isSending && index == 0) {
                  return const _TypingBubble();
                }
                final offset = state.isSending ? 1 : 0;
                final messageIndex =
                    state.messages.length - 1 - (index - offset);
                return _MessageBubble(message: state.messages[messageIndex]);
              },
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ActionChip(
              label: Text(_suggestions[index]),
              onPressed: hasApiKey
                  ? () => context
                      .read<ChatBloc>()
                      .add(ChatMessageSubmitted(_suggestions[index]))
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _Composer(enabled: hasApiKey),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  final bool enabled;
  const _Composer({required this.enabled});
  @override
  Widget build(BuildContext context) => BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) => Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey(state.inputRevision),
                  initialValue: state.draft,
                  enabled: enabled && !state.isSending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onChanged: (value) =>
                      context.read<ChatBloc>().add(ChatDraftChanged(value)),
                  onFieldSubmitted: (_) => context
                      .read<ChatBloc>()
                      .add(const ChatMessageSubmitted()),
                  decoration: InputDecoration(
                    hintText:
                        enabled ? 'Nhập lệnh cho đèn…' : 'Cần cấu hình API key',
                    prefixIcon: const Icon(Icons.auto_awesome_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Gửi tin nhắn',
                onPressed:
                    enabled && !state.isSending && state.draft.trim().isNotEmpty
                        ? () => context
                            .read<ChatBloc>()
                            .add(const ChatMessageSubmitted())
                        : null,
                icon: state.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: EdgeInsets.only(
            bottom: 12,
            left: message.isUser ? 48 : 0,
            right: message.isUser ? 0 : 48),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isUser ? scheme.primary : scheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: message.isUser
              ? null
              : Border.all(color: scheme.outline.withValues(alpha: .6)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.content,
              style: TextStyle(
                  color: message.isUser ? scheme.onPrimary : scheme.onSurface,
                  height: 1.45)),
          if (message.command != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_rounded,
                  size: 16,
                  color: message.isUser ? scheme.onPrimary : scheme.primary),
              const SizedBox(width: 6),
              Text('Đã nhận lệnh điều khiển',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          message.isUser ? scheme.onPrimary : scheme.primary)),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Chip(
            avatar: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            label: Text('Đang xử lý…'),
          ),
        ),
      );
}
