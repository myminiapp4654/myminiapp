import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_room_service.dart';
import '../theme/pixel_ui.dart';
import 'chat_room_screen.dart';

class ChatRoomsListScreen extends StatefulWidget {
  const ChatRoomsListScreen({super.key});

  @override
  State<ChatRoomsListScreen> createState() => _ChatRoomsListScreenState();
}

class _ChatRoomsListScreenState extends State<ChatRoomsListScreen> {
  final _service = ChatRoomService();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool hasPassword = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: kPanel,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: pixelText('YANGI CHAT XONA', kAccent, 14),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(
                    color: kWhite,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold),
                autofocus: true,
                decoration: pixelInputDecoration('XONA NOMI'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: hasPassword,
                    onChanged: (v) => setDlg(() => hasPassword = v),
                    activeThumbColor: kAccent,
                    inactiveThumbColor: kDim,
                    inactiveTrackColor: kBorder,
                  ),
                  pixelText('PAROL QO\'YISH', kDim, 10),
                ],
              ),
              if (hasPassword) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  style: const TextStyle(
                      color: kWhite,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold),
                  obscureText: true,
                  decoration: pixelInputDecoration('PAROL'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: pixelText('BEKOR', kDim, 11),
            ),
            GestureDetector(
              onTap: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final pass = hasPassword ? passCtrl.text.trim() : null;
                Navigator.pop(ctx);
                final code = await _service.createChatRoom(name, pass);
                if (mounted) _showShareSheet(code, name);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: kAccent,
                child: pixelText('YARATISH', kBg, 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShareSheet(String code, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pixelText('[ XONA YARATILDI ]', kAccent, 16),
            const SizedBox(height: 8),
            pixelText('"${name.toUpperCase()}"', kWhite, 13),
            const SizedBox(height: 20),
            pixelContainer(
              borderColor: kAccent.withValues(alpha: 0.5),
              color: kAccent.withValues(alpha: 0.06),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  pixelText('XONA KODI:', kDim, 10),
                  const SizedBox(height: 8),
                  pixelText(code, kAccent, 32),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: 'Oyinim - "$name" chat xonasiga qo\'shiling!\nKod: $code'));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nusxalandi!')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        border: Border.all(color: kAccent, width: 1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy, color: kAccent, size: 14),
                          const SizedBox(width: 6),
                          pixelText('KODNI NUSXALASH', kAccent, 11),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            pixelButton(
              label: '► XONAGA KIRISH',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ChatRoomScreen(roomId: code, roomName: name)),
                );
              },
              color: kAccent,
              textColor: kBg,
              borderColor: kAccent,
              fontSize: 14,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('6 belgili kod kiriting')));
      return;
    }
    final doc = await _service.roomStream(code).first;
    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xona topilmadi')));
      }
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    final hasPassword = data['hasPassword'] as bool;
    final roomName = data['name'] as String;
    if (hasPassword) {
      await _promptPasswordAndJoin(code, roomName);
    } else {
      final err = await _service.joinChatRoom(code, null);
      if (err != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      }
      _codeController.clear();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatRoomScreen(roomId: code, roomName: roomName)),
        );
      }
    }
  }

  Future<void> _promptPasswordAndJoin(String code, String roomName) async {
    final passCtrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kPanel,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: pixelText(roomName.toUpperCase(), kWarn, 13),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            pixelText('[ PAROLLI XONA ]', kDim, 10),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(
                  color: kWhite,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold),
              decoration: pixelInputDecoration('PAROLNI KIRITING'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: pixelText('BEKOR', kDim, 11),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, passCtrl.text.trim()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: kAccent,
              child: pixelText('KIRISH', kBg, 11),
            ),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    final err = await _service.joinChatRoom(code, entered);
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }
    _codeController.clear();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ChatRoomScreen(roomId: code, roomName: roomName)),
      );
    }
  }

  Future<void> _openRoom(String roomId, Map<String, dynamic> data) async {
    final name = data['name'] as String;
    final hasPassword = data['hasPassword'] as bool;
    if (hasPassword) {
      await _promptPasswordAndJoin(roomId, name);
    } else {
      final err = await _service.joinChatRoom(roomId, null);
      if (err != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      }
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatRoomScreen(roomId: roomId, roomName: name)),
        );
      }
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
        title: pixelText('CHAT XONALAR', kAccent, 13),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _showCreateDialog,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  border: Border.all(color: kAccent, width: 1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: kAccent, size: 14),
                    const SizedBox(width: 4),
                    pixelText('YARATISH', kAccent, 10),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        letterSpacing: 3,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold),
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    decoration: pixelInputDecoration('KOD KIRITING').copyWith(
                      counterText: '',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    ],
                    onSubmitted: (_) => _joinByCode(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _joinByCode,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: kAccent,
                      border: Border.all(color: kAccent, width: 2),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Center(child: pixelText('KIRISH', kBg, 11)),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: kBorder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Container(height: 1, color: kBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: pixelText('MAVJUD XONALAR', kDim, 9),
              ),
              Expanded(child: Container(height: 1, color: kBorder)),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.chatRoomsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return pixelLoading();
                final rooms = snapshot.data!.docs;
                if (rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        pixelText('[ HALI XONA YO\'Q ]', kDim, 16),
                        const SizedBox(height: 16),
                        pixelButton(
                          label: '+ XONA YARATISH',
                          onTap: _showCreateDialog,
                          color: kAccent,
                          textColor: kBg,
                          borderColor: kAccent,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: rooms.length,
                  itemBuilder: (ctx, i) {
                    final data = rooms[i].data() as Map<String, dynamic>;
                    return _buildRoomItem(rooms[i].id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomItem(String roomId, Map<String, dynamic> data) {
    final name = data['name'] as String;
    final hasPassword = data['hasPassword'] as bool;
    final memberCount = data['memberCount'] as int;
    final lastMessage = data['lastMessage'] as String? ?? '';
    final creatorName = data['creatorName'] as String? ?? '';
    final isFull = memberCount >= 20;

    return GestureDetector(
      onTap: isFull ? null : () => _openRoom(roomId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFull ? kPanel.withValues(alpha: 0.5) : kPanel,
          border: Border.all(
            color: isFull
                ? kBorder.withValues(alpha: 0.3)
                : kBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.zero,
          boxShadow: isFull
              ? null
              : [
                  BoxShadow(
                    color: kAccent.withValues(alpha: 0.08),
                    blurRadius: 0,
                    offset: const Offset(2, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              color: isFull
                  ? kDanger.withValues(alpha: 0.08)
                  : kAccent.withValues(alpha: 0.1),
              child: Center(
                child: Icon(
                  hasPassword ? Icons.lock_outline : Icons.chat_bubble_outline,
                  color: isFull ? kDanger : kAccent,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.toUpperCase(),
                          style: TextStyle(
                            color: isFull ? kDim : kWhite,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFull
                              ? kDanger.withValues(alpha: 0.1)
                              : kAccent.withValues(alpha: 0.1),
                          border: Border.all(
                            color: isFull ? kDanger : kAccent,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: pixelText(
                          '$memberCount/20',
                          isFull ? kDanger : kAccent,
                          9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage.isNotEmpty
                        ? lastMessage
                        : '$creatorName tomonidan ochilgan',
                    style: const TextStyle(
                        color: kDim, fontSize: 11, fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isFull ? Icons.block : Icons.arrow_forward_ios,
              color: isFull ? kDanger : kBorder,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}
