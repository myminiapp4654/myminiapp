import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/dm_service.dart';
import '../theme/pixel_ui.dart';
import 'dm_screen.dart';

class DmListScreen extends StatelessWidget {
  const DmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = DmService();

    return Scaffold(
      backgroundColor: kBg,
      appBar: pixelAppBar(title: 'SHAXSIY CHATLAR'),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.myDmsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return pixelLoading();

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['lastMessageAt'];
              final bTime = bData['lastMessageAt'];
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return (bTime as dynamic).compareTo(aTime as dynamic);
            });

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    pixelText('[ SHAXSIY CHATLAR ]', kDim, 16),
                    const SizedBox(height: 16),
                    pixelText('HALI CHAT YO\'Q', kWhite, 13),
                    const SizedBox(height: 8),
                    pixelText(
                      'GURUH CHATIDAGI O\'YINCHIGA\nBOSIB SHAXSIY CHAT BOSHLANG',
                      kDim, 10,
                    ),
                    const SizedBox(height: 24),
                    pixelButton(
                      label: '◄ ORQAGA',
                      onTap: () => Navigator.pop(context),
                      color: kBg,
                      textColor: kAccent,
                      borderColor: kAccent,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final names = data['names'] as Map<String, dynamic>? ?? {};
              final otherUid = (data['participants'] as List)
                  .firstWhere((uid) => uid != service.myUid,
                      orElse: () => service.myUid)
                  .toString();
              final otherName = names[otherUid] as String? ?? 'Mehmon';
              final lastMessage = data['lastMessage'] as String? ?? '';
              final chatId = docs[i].id;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          DmScreen(chatId: chatId, otherName: otherName)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPanel,
                    border: Border.all(color: kBorder, width: 1),
                    borderRadius: BorderRadius.zero,
                    boxShadow: [
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
                        color: kAccent.withValues(alpha: 0.12),
                        child: Center(
                          child: pixelText(
                            otherName.isEmpty
                                ? '?'
                                : otherName[0].toUpperCase(),
                            kAccent,
                            16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            pixelText(
                              otherName.toUpperCase(),
                              kWhite,
                              12,
                              align: TextAlign.left,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : 'Xabar yo\'q',
                              style: const TextStyle(
                                  color: kDim,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: kBorder, size: 12),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
