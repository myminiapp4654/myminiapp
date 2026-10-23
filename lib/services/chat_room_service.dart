import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatRoomService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  String _genCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createChatRoom(String name, String? password) async {
    final code = _genCode();
    final ref = _db.collection('chat_rooms').doc(code);
    await ref.set({
      'id': code,
      'name': name,
      'hasPassword': password != null && password.isNotEmpty,
      'password': password ?? '',
      'members': {myUid: {'name': myName}},
      'memberCount': 1,
      'maxMembers': 20,
      'createdBy': myUid,
      'creatorName': myName,
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  // Returns null on success, error string on failure
  Future<String?> joinChatRoom(String roomId, String? password) async {
    final ref = _db.collection('chat_rooms').doc(roomId);
    final doc = await ref.get();
    if (!doc.exists) return 'Xona topilmadi';
    final data = doc.data()!;

    final members = data['members'] as Map;
    if (members.containsKey(myUid)) return null;

    if ((data['memberCount'] as int) >= (data['maxMembers'] as int)) {
      return 'Xona to\'la (20/20)';
    }

    if (data['hasPassword'] as bool) {
      if (password == null || password.isEmpty || password != data['password']) {
        return 'Parol noto\'g\'ri';
      }
    }

    await ref.update({
      'members.$myUid': {'name': myName},
      'memberCount': FieldValue.increment(1),
    });
    return null;
  }

  Future<String> uploadImage(String roomId, File file) async {
    final name = '${myUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref('chat_rooms/$roomId/$name');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> sendMessage(
    String roomId,
    String text, {
    String? imageUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    final batch = _db.batch();
    final msgRef = _db
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    final data = <String, dynamic>{
      'uid': myUid,
      'name': myName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (replyTo != null) data['replyTo'] = replyTo;
    batch.set(msgRef, data);
    batch.update(_db.collection('chat_rooms').doc(roomId), {
      'lastMessage':
          imageUrl != null && text.isEmpty ? '📷 Rasm' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> deleteMessage(
      String roomId, String messageId, String? imageUrl) async {
    if (imageUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (_) {}
    }
    await _db
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> clearChat(String roomId) async {
    final snap = await _db
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    if (snap.docs.isNotEmpty) await batch.commit();
    await _db.collection('chat_rooms').doc(roomId).update({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveChatRoom(String roomId) async {
    await _db.collection('chat_rooms').doc(roomId).update({
      'members.$myUid': FieldValue.delete(),
      'memberCount': FieldValue.increment(-1),
    });
  }

  Stream<QuerySnapshot> chatRoomsStream() => _db
      .collection('chat_rooms')
      .orderBy('lastMessageAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot> messagesStream(String roomId) => _db
      .collection('chat_rooms')
      .doc(roomId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .limitToLast(100)
      .snapshots();

  Future<void> toggleReaction(
      String roomId, String messageId, String emoji) async {
    final ref = _db
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final reactions = Map<String, dynamic>.from(
          (snap.data()?['reactions'] as Map?) ?? {});
      final uids = List<String>.from(reactions[emoji] ?? []);
      if (uids.contains(myUid)) {
        uids.remove(myUid);
      } else {
        uids.add(myUid);
      }
      if (uids.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = uids;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  Stream<DocumentSnapshot> roomStream(String roomId) =>
      _db.collection('chat_rooms').doc(roomId).snapshots();
}
