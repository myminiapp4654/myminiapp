import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class DmService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;
  String get myName => _auth.currentUser!.displayName ?? 'Mehmon';

  // Chat ID = sorted UIDs separated by "_"
  String _chatId(String otherUid) {
    final ids = [myUid, otherUid]..sort();
    return ids.join('_');
  }

  Future<String> getOrCreateDm(String otherUid, String otherName) async {
    final chatId = _chatId(otherUid);
    final ref = _db.collection('direct_messages').doc(chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'id': chatId,
        'participants': [myUid, otherUid],
        'names': {myUid: myName, otherUid: otherName},
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return chatId;
  }

  Future<String> uploadImage(String chatId, XFile file) async {
    final name = '${myUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref('direct_messages/$chatId/$name');
    final bytes = await file.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> sendMessage(
    String chatId,
    String text, {
    String? imageUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    final batch = _db.batch();
    final msgRef = _db
        .collection('direct_messages')
        .doc(chatId)
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
    batch.update(_db.collection('direct_messages').doc(chatId), {
      'lastMessage':
          imageUrl != null && text.isEmpty ? '📷 Rasm' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'names.$myUid': myName,
    });
    await batch.commit();
  }

  Future<void> deleteMessage(
      String chatId, String messageId, String? imageUrl) async {
    if (imageUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (_) {}
    }
    await _db
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> clearChat(String chatId) async {
    final snap = await _db
        .collection('direct_messages')
        .doc(chatId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    if (snap.docs.isNotEmpty) await batch.commit();
    await _db.collection('direct_messages').doc(chatId).update({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> messagesStream(String chatId) => _db
      .collection('direct_messages')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .limitToLast(100)
      .snapshots();

  // No composite index needed — sort client-side
  Stream<QuerySnapshot> myDmsStream() => _db
      .collection('direct_messages')
      .where('participants', arrayContains: myUid)
      .snapshots();

  Future<void> toggleReaction(
      String chatId, String messageId, String emoji) async {
    final ref = _db
        .collection('direct_messages')
        .doc(chatId)
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

  Stream<DocumentSnapshot> dmStream(String chatId) =>
      _db.collection('direct_messages').doc(chatId).snapshots();
}
