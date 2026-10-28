import 'package:antigua_business_map/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A chat between one customer and one business.
class Conversation {
  const Conversation({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.customerId,
    required this.blocked,
    required this.lastMessageAt,
    required this.unread,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String customerId;
  final bool blocked;
  final DateTime lastMessageAt;

  /// Messages from the other side not yet read.
  final int unread;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: '${m['id']}',
    senderId: '${m['sender_id']}',
    body: '${m['body']}',
    createdAt: DateTime.parse('${m['created_at']}'),
    readAt: m['read_at'] == null ? null : DateTime.parse('${m['read_at']}'),
  );

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
}

/// In-app messages (2026-10-28 redesign). Privacy and limits are enforced
/// by the database: only the two sides read a conversation, a blocked
/// customer cannot send, 30 messages an hour per sender.
class MessagesRepository {
  MessagesRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _db {
    final client = _client;
    if (client != null) return client;
    if (!AppConfig.supabaseConfigured) throw const BackendNotConfigured();
    return Supabase.instance.client;
  }

  String? get currentUserId {
    try {
      return _db.auth.currentUser?.id;
    } on BackendNotConfigured {
      return null;
    }
  }

  Future<List<Conversation>> _load(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
  ) async {
    final uid = currentUserId;
    final rows = await query.order('last_message_at', ascending: false);
    return [
      for (final r in rows)
        Conversation(
          id: '${r['id']}',
          businessId: '${r['business_id']}',
          businessName: (r['businesses'] as Map?)?['name']?.toString() ?? '',
          customerId: '${r['customer_id']}',
          blocked: (r['blocked'] as bool?) ?? false,
          lastMessageAt: DateTime.parse('${r['last_message_at']}'),
          unread: [
            for (final m in (r['messages'] as List?) ?? const [])
              if (m is Map && m['read_at'] == null && m['sender_id'] != uid) m,
          ].length,
        ),
    ];
  }

  static const _select =
      'id, business_id, customer_id, blocked, last_message_at, '
      'businesses(name), messages(sender_id, read_at)';

  /// The signed-in customer's conversations with businesses.
  Future<List<Conversation>> mine() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    return _load(
      _db.from('conversations').select(_select).eq('customer_id', uid),
    );
  }

  /// A business's conversations with customers.
  Future<List<Conversation>> forBusiness(String businessId) => _load(
    _db.from('conversations').select(_select).eq('business_id', businessId),
  );

  /// Live messages in a conversation, oldest first.
  Stream<List<ChatMessage>> watch(String conversationId) => _db
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.map(ChatMessage.fromMap).toList(growable: false));

  /// Sends to a business (first message opens the conversation) or into an
  /// existing conversation. Returns the conversation id.
  Future<String> send(
    String body, {
    String? businessId,
    String? conversationId,
  }) async =>
      '${await _db.rpc<dynamic>(
        'send_message',
        params: {
          'p_body': body,
          'p_business': businessId,
          'p_conversation': conversationId,
        },
      )}';

  Future<void> markRead(String conversationId) => _db.rpc<void>(
    'mark_conversation_read',
    params: {'p_conversation': conversationId},
  );

  Future<void> setBlocked(String conversationId, {required bool blocked}) =>
      _db.rpc<void>(
        'set_conversation_blocked',
        params: {'p_conversation': conversationId, 'p_blocked': blocked},
      );

  Future<void> report(String conversationId, String reason) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.from('conversation_reports').upsert({
      'conversation_id': conversationId,
      'user_id': uid,
      'reason': reason.trim(),
    });
  }

  /// The existing conversation with a business, if any.
  Future<String?> existingWith(String businessId) async {
    final uid = currentUserId;
    if (uid == null) return null;
    final rows = await _db
        .from('conversations')
        .select('id')
        .eq('business_id', businessId)
        .eq('customer_id', uid)
        .limit(1);
    return rows.isEmpty ? null : '${rows.first['id']}';
  }
}

String messageErrorMessage(Object error) => switch (error) {
  PostgrestException(:final message) when message.isNotEmpty => message,
  _ => 'Could not send. Check your signal and try again.',
};

final messagesRepositoryProvider = Provider<MessagesRepository>(
  (ref) => MessagesRepository(),
);

final myConversationsProvider = FutureProvider<List<Conversation>>(
  (ref) => ref.watch(messagesRepositoryProvider).mine(),
);

// Inferred: the family type is only nameable via riverpod/src.
// ignore: specify_nonobvious_property_types
final businessConversationsProvider =
    FutureProvider.family<List<Conversation>, String>(
      (ref, businessId) =>
          ref.watch(messagesRepositoryProvider).forBusiness(businessId),
    );
