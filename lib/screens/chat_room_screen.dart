import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_room_service.dart';
import '../services/dm_service.dart';
import '../theme/pixel_ui.dart';
import '../widgets/swipe_to_reply.dart';
import 'dm_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatRoomScreen(
      {super.key, required this.roomId, required this.roomName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _service = ChatRoomService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _uploadingImage = false;
  Map<String, dynamic>? _replyTo;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    _textController.clear();
    final reply = _replyTo;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    await _service.sendMessage(widget.roomId, text, replyTo: reply);
    if (mounted) {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: kAccent),
              title: pixelText('GALEREYADAN', kWhite, 12),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kAccent),
              title: pixelText('KAMERADAN', kWhite, 12),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 72);
    if (picked == null) return;

    final reply = _replyTo;
    setState(() {
      _uploadingImage = true;
      _replyTo = null;
    });
    try {
      final url = await _service.uploadImage(widget.roomId, File(picked.path));
      await _service.sendMessage(widget.roomId, '', imageUrl: url, replyTo: reply);
      if (mounted) _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _showMembers(Map members) {
    final dmService = DmService();
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pixelText('A\'ZOLAR (${members.length}/20)', kAccent, 12),
            const SizedBox(height: 16),
            ...members.entries.map((e) {
              final p = e.value as Map;
              final isMe = e.key == _service.myUid;
              final otherName = p['name'] as String;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      color: kAccent.withValues(alpha: 0.15),
                      child: Center(
                        child: pixelText(
                          otherName.isEmpty
                              ? '?'
                              : otherName[0].toUpperCase(),
                          kAccent,
                          12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: pixelText(
                        isMe
                            ? '${otherName.toUpperCase()} (SEN)'
                            : otherName.toUpperCase(),
                        isMe ? kAccent : kWhite,
                        11,
                        align: TextAlign.left,
                      ),
                    ),
                    if (isMe)
                      Container(
                        width: 8,
                        height: 8,
                        color: kAccent,
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          final chatId = await dmService.getOrCreateDm(
                              e.key, otherName);
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DmScreen(
                                      chatId: chatId,
                                      otherName: otherName)),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kBlue.withValues(alpha: 0.1),
                            border: Border.all(color: kBlue, width: 1),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: pixelText('DM', kBlue, 10),
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    backgroundColor: kPanel,
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
                    title: pixelText('CHATNI TOZALASH', kWarn, 13),
                    content: pixelText(
                        'Barcha xabarlar o\'chiriladi. Davom etasizmi?',
                        kWhite, 11),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: pixelText('BEKOR', kDim, 11),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(d, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          color: kDanger,
                          child: pixelText('O\'CHIRISH', kWhite, 11),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.clearChat(widget.roomId);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: kWarn, width: 1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Center(child: pixelText('CHATNI TOZALASH', kWarn, 11)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final nav = Navigator.of(context);
                await _service.leaveChatRoom(widget.roomId);
                nav.pop();
                nav.pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: kDanger, width: 1),
                  borderRadius: BorderRadius.zero,
                ),
                child:
                    Center(child: pixelText('XONADAN CHIQISH', kDanger, 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _service.roomStream(widget.roomId),
      builder: (context, roomSnap) {
        final members = roomSnap.hasData && roomSnap.data!.exists
            ? (roomSnap.data!.data() as Map<String, dynamic>)['members'] as Map
            : <String, dynamic>{};

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kPanel,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kAccent),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                pixelText(widget.roomName.toUpperCase(), kAccent, 12),
                pixelText('${members.length}/20 ODAM', kDim, 9),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.group, color: kAccent, size: 20),
                onPressed: () => _showMembers(members),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child:
                  Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _service.messagesStream(widget.roomId),
                  builder: (context, snap) {
                    if (!snap.hasData) return pixelLoading();
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: pixelText(
                            'HALI XABAR YO\'Q.\nBIRINCHI BO\'LING!',
                            kDim, 12),
                      );
                    }
                    _scrollToBottom();
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final msg = docs[i].data() as Map<String, dynamic>;
                        final isMe = msg['uid'] == _service.myUid;
                        return _buildMessage(msg, isMe,
                            messageId: docs[i].id,
                            showName: i == 0 ||
                                (docs[i - 1].data()
                                        as Map<String, dynamic>)['uid'] !=
                                    msg['uid']);
                      },
                    );
                  },
                ),
              ),
              _buildInput(),
            ],
          ),
        );
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg, String messageId) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉'];
    final isMe = msg['uid'] == _service.myUid;
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: emojis
                .map((e) => GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _service.toggleReaction(widget.roomId, messageId, e);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ))
                .toList(),
          ),
          Container(height: 1, color: kBorder),
          ListTile(
            leading: const Icon(Icons.reply, color: kDim),
            title: pixelText('JAVOB BERISH', kWhite, 11),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _replyTo = {
                    'name': msg['name'],
                    'text': msg['text'] ?? '',
                    'imageUrl': msg['imageUrl'],
                    'uid': msg['uid'],
                  });
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kDanger),
              title: pixelText('O\'CHIRISH', kDanger, 11),
              onTap: () {
                Navigator.pop(ctx);
                _service.deleteMessage(
                    widget.roomId, messageId, msg['imageUrl'] as String?);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReplySnippet(Map replyTo) {
    final text = replyTo['text'] as String? ?? '';
    final hasImage = replyTo['imageUrl'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1F0D),
        border: Border(left: BorderSide(color: kAccent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pixelText(
            (replyTo['name'] as String? ?? '').toUpperCase(),
            kAccent,
            9,
            align: TextAlign.left,
          ),
          Text(
            hasImage && text.isEmpty ? '[RASM]' : text,
            style: const TextStyle(color: kDim, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(Map<String, dynamic> msg, String messageId) {
    final reactions = msg['reactions'] as Map?;
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((e) {
          final uids = List<String>.from(e.value as List);
          final iMine = uids.contains(_service.myUid);
          return GestureDetector(
            onTap: () =>
                _service.toggleReaction(widget.roomId, messageId, e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: iMine
                    ? kAccent.withValues(alpha: 0.15)
                    : kPanel,
                border: Border.all(
                  color: iMine ? kAccent : kBorder,
                  width: 1,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Text('${e.key} ${uids.length}',
                  style: const TextStyle(fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isMe,
      {required bool showName, required String messageId}) {
    final replyTo = msg['replyTo'] as Map?;
    final imageUrl = msg['imageUrl'] as String?;
    final text = msg['text'] as String? ?? '';

    return SwipeToReply(
      onReply: () => setState(() => _replyTo = {
            'name': msg['name'],
            'text': text,
            'imageUrl': imageUrl,
            'uid': msg['uid'],
          }),
      child: Padding(
        padding: EdgeInsets.only(top: showName ? 10 : 2, bottom: 2),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showName) ...[
              Container(
                width: 28,
                height: 28,
                color: kAccent.withValues(alpha: 0.15),
                child: Center(
                  child: pixelText(
                    (msg['name'] as String).isEmpty
                        ? '?'
                        : (msg['name'] as String)[0].toUpperCase(),
                    kAccent,
                    11,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else if (!isMe)
              const SizedBox(width: 34),
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: pixelText(
                        (msg['name'] as String).toUpperCase(),
                        kAccent,
                        9,
                        align: TextAlign.left,
                      ),
                    ),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(msg, messageId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? kAccent.withValues(alpha: 0.12)
                            : kPanel,
                        border: Border.all(
                          color: isMe
                              ? kAccent.withValues(alpha: 0.4)
                              : kBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.zero,
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? kAccent.withValues(alpha: 0.1)
                                : Colors.transparent,
                            blurRadius: 0,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyTo != null) _buildReplySnippet(replyTo),
                          if (imageUrl != null)
                            ClipRect(
                              child: Image.network(
                                imageUrl,
                                width: 220,
                                fit: BoxFit.cover,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : SizedBox(
                                            width: 220,
                                            height: 140,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: kAccent,
                                                value: progress.expectedTotalBytes !=
                                                        null
                                                    ? progress
                                                            .cumulativeBytesLoaded /
                                                        progress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          ),
                              ),
                            ),
                          if (text.isNotEmpty)
                            Padding(
                              padding: imageUrl != null
                                  ? const EdgeInsets.only(top: 6)
                                  : EdgeInsets.zero,
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? kAccent : kWhite,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _buildReactions(msg, messageId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyTo != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            color: kPanel,
            child: Row(
              children: [
                Container(width: 3, height: 36, color: kAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pixelText(
                        (_replyTo!['name'] as String).toUpperCase(),
                        kAccent,
                        9,
                        align: TextAlign.left,
                      ),
                      Text(
                        _replyTo!['imageUrl'] != null &&
                                (_replyTo!['text'] as String).isEmpty
                            ? '[RASM]'
                            : _replyTo!['text'] as String,
                        style:
                            const TextStyle(color: kDim, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: kDim, size: 18),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 4,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: kPanel,
            border: Border(
                top: BorderSide(
                    color: _replyTo != null ? Colors.transparent : kBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: _uploadingImage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kAccent))
                    : const Icon(Icons.image_outlined, color: kAccent),
                onPressed: _uploadingImage ? null : _pickAndSendImage,
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(
                      color: kWhite, fontFamily: 'monospace', fontSize: 12),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: pixelInputDecoration('XABAR YOZING...'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: kAccent,
                    border: Border.all(color: kAccent, width: 2),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Icon(Icons.send, color: kBg, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
