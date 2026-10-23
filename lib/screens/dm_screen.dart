import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/dm_service.dart';
import '../theme/pixel_ui.dart';
import '../widgets/swipe_to_reply.dart';

class DmScreen extends StatefulWidget {
  final String chatId;
  final String otherName;

  const DmScreen({super.key, required this.chatId, required this.otherName});

  @override
  State<DmScreen> createState() => _DmScreenState();
}

class _DmScreenState extends State<DmScreen> {
  final _service = DmService();
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
    await _service.sendMessage(widget.chatId, text, replyTo: reply);
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
      final url = await _service.uploadImage(widget.chatId, File(picked.path));
      await _service.sendMessage(widget.chatId, '', imageUrl: url, replyTo: reply);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kPanel,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              color: kBlue.withValues(alpha: 0.15),
              child: Center(
                child: pixelText(
                  widget.otherName.isEmpty
                      ? '?'
                      : widget.otherName[0].toUpperCase(),
                  kBlue,
                  13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            pixelText(widget.otherName.toUpperCase(), kWhite, 12),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined,
                color: kWarn, size: 20),
            tooltip: 'Chatni tozalash',
            onPressed: _confirmClearChat,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: kBlue.withValues(alpha: 0.4)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.messagesStream(widget.chatId),
              builder: (context, snap) {
                if (!snap.hasData) return pixelLoading();
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: pixelText(
                      '${widget.otherName.toUpperCase()} BILAN\nSUHBATNI BOSHLANG!',
                      kDim,
                      12,
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final msg = docs[i].data() as Map<String, dynamic>;
                    final isMe = msg['uid'] == _service.myUid;
                    return _buildMessage(msg, isMe, messageId: docs[i].id);
                  },
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
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
                        _service.toggleReaction(widget.chatId, messageId, e);
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
                    widget.chatId, messageId, msg['imageUrl'] as String?);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: kPanel,
        shape:
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: pixelText('CHATNI TOZALASH', kWarn, 13),
        content: pixelText(
            'Barcha xabarlar o\'chiriladi. Davom etasizmi?', kWhite, 11),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: pixelText('BEKOR', kDim, 11),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(d, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: kDanger,
              child: pixelText('O\'CHIRISH', kWhite, 11),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.clearChat(widget.chatId);
    }
  }

  Widget _buildReplySnippet(Map replyTo) {
    final text = replyTo['text'] as String? ?? '';
    final hasImage = replyTo['imageUrl'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1F),
        border: Border(left: BorderSide(color: kBlue, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pixelText(
            (replyTo['name'] as String? ?? '').toUpperCase(),
            kBlue,
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
                _service.toggleReaction(widget.chatId, messageId, e.key),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: iMine
                    ? kBlue.withValues(alpha: 0.15)
                    : kPanel,
                border: Border.all(
                  color: iMine ? kBlue : kBorder,
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
      {required String messageId}) {
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
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(msg, messageId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe
                            ? kBlue.withValues(alpha: 0.12)
                            : kPanel,
                        border: Border.all(
                          color: isMe
                              ? kBlue.withValues(alpha: 0.4)
                              : kBorder,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.zero,
                        boxShadow: [
                          BoxShadow(
                            color: isMe
                                ? kBlue.withValues(alpha: 0.1)
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
                                                color: kBlue,
                                                value: progress
                                                            .expectedTotalBytes !=
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
                                  color: isMe ? kBlue : kWhite,
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
                Container(width: 3, height: 36, color: kBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pixelText(
                        (_replyTo!['name'] as String).toUpperCase(),
                        kBlue,
                        9,
                        align: TextAlign.left,
                      ),
                      Text(
                        _replyTo!['imageUrl'] != null &&
                                (_replyTo!['text'] as String).isEmpty
                            ? '[RASM]'
                            : _replyTo!['text'] as String,
                        style: const TextStyle(color: kDim, fontSize: 11),
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
                            strokeWidth: 2, color: kBlue))
                    : const Icon(Icons.image_outlined, color: kBlue),
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
                    color: kBlue,
                    border: Border.all(color: kBlue, width: 2),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Icon(Icons.send, color: kWhite, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
