import 'package:antigua_business_map/core/theme/app_colors.dart';
import 'package:antigua_business_map/core/theme/app_spacing.dart';
import 'package:antigua_business_map/core/theme/app_text.dart';
import 'package:antigua_business_map/services/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _stamp(DateTime t) {
  final local = t.toLocal();
  final now = DateTime.now();
  final today =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  return today
      ? DateFormat.jm().format(local)
      : DateFormat('d MMM').format(local);
}

/// Conversations: a customer's with businesses, or a business's with
/// customers (when [businessId] is given).
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({this.businessId, super.key});

  final String? businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final id = businessId;
    final list = id == null
        ? ref.watch(myConversationsProvider)
        : ref.watch(businessConversationsProvider(id));

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: palette.app,
      ),
      body: list.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: palette.red)),
        error: (_, _) => const Center(child: Text('Could not load messages.')),
        data: (convs) => convs.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.huge),
                  child: Text(
                    id == null
                        ? 'No messages yet. Tap Message on any business page.'
                        : 'No messages from customers yet.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(color: palette.muted),
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => id == null
                    ? ref.invalidate(myConversationsProvider)
                    : ref.invalidate(businessConversationsProvider(id)),
                child: ListView.separated(
                  itemCount: convs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = convs[i];
                    final title = id == null ? c.businessName : 'Customer';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: palette.red,
                        child: Icon(
                          id == null ? Icons.storefront : Icons.person,
                          color: palette.onRed,
                        ),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: c.unread > 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        c.blocked ? 'Blocked' : _stamp(c.lastMessageAt),
                      ),
                      trailing: c.unread > 0
                          ? CircleAvatar(
                              radius: 11,
                              backgroundColor: palette.red,
                              child: Text(
                                '${c.unread}',
                                style: AppText.caption.copyWith(
                                  color: palette.onRed,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : null,
                      onTap: () async {
                        await context.push(
                          '/messages/${c.id}?title=${Uri.encodeComponent(title)}'
                          '${id == null ? '' : '&business=$id'}',
                        );
                        if (id == null) {
                          ref.invalidate(myConversationsProvider);
                        } else {
                          ref.invalidate(businessConversationsProvider(id));
                        }
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// One conversation, live. Opened either on an existing conversation, or on
/// a business with no conversation yet (the first message creates it).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.title,
    this.conversationId,
    this.businessId,
    this.asBusiness = false,
    super.key,
  });

  final String title;
  final String? conversationId;

  /// The business being written to, before any conversation exists.
  final String? businessId;

  /// Opened from the business side, which can block the customer.
  final bool asBusiness;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  String? _conversationId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId == null && widget.businessId != null) {
      ref
          .read(messagesRepositoryProvider)
          .existingWith(widget.businessId!)
          .then((id) {
            if (mounted && id != null) setState(() => _conversationId = id);
          });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await ref
          .read(messagesRepositoryProvider)
          .send(
            body,
            businessId: _conversationId == null ? widget.businessId : null,
            conversationId: _conversationId,
          );
      _text.clear();
      if (mounted) setState(() => _conversationId = id);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(String value) async {
    final id = _conversationId;
    if (id == null) return;
    final repo = ref.read(messagesRepositoryProvider);
    if (value == 'block' || value == 'unblock') {
      await repo.setBlocked(id, blocked: value == 'block');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value == 'block'
                  ? 'Blocked. They can no longer message you.'
                  : 'Unblocked.',
            ),
          ),
        );
      }
    } else if (value == 'report') {
      final c = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Report this conversation'),
          content: TextField(
            controller: c,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Harassment, scam, spam…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, c.text),
              child: const Text('Report'),
            ),
          ],
        ),
      );
      c.dispose();
      if (reason != null && reason.trim().length >= 3) {
        await repo.report(id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reported. The team can now read this chat.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final me = ref.read(messagesRepositoryProvider).currentUserId;
    final id = _conversationId;

    return Scaffold(
      backgroundColor: palette.app,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: palette.app,
        actions: [
          if (id != null)
            PopupMenuButton<String>(
              onSelected: _menu,
              itemBuilder: (_) => [
                if (widget.asBusiness) ...[
                  const PopupMenuItem(value: 'block', child: Text('Block')),
                  const PopupMenuItem(value: 'unblock', child: Text('Unblock')),
                ],
                const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: id == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.huge),
                      child: Text(
                        'Ask about prices, opening times or a booking. The '
                        'business replies here.',
                        textAlign: TextAlign.center,
                        style: AppText.bodyMedium.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  )
                : StreamBuilder<List<ChatMessage>>(
                    stream: ref.read(messagesRepositoryProvider).watch(id),
                    builder: (context, snap) {
                      final messages = snap.data ?? const <ChatMessage>[];
                      if (messages.any(
                        (m) => m.senderId != me && m.readAt == null,
                      )) {
                        ref.read(messagesRepositoryProvider).markRead(id);
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(Insets.md),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[messages.length - 1 - i];
                          final mine = m.senderId == me;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: mine ? palette.red : palette.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: mine
                                    ? null
                                    : Border.all(color: palette.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    m.body,
                                    style: AppText.bodyMedium.copyWith(
                                      color: mine ? palette.onRed : palette.ink,
                                    ),
                                  ),
                                  Text(
                                    _stamp(m.createdAt) +
                                        (mine && m.readAt != null
                                            ? ' · Read'
                                            : ''),
                                    style: AppText.caption.copyWith(
                                      fontSize: 10,
                                      color: mine
                                          ? palette.onRed.withValues(alpha: 0.7)
                                          : palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
