import 'package:flutter/material.dart';

import '../games/battleship/battleship_screen.dart';
import '../games/chain/chain_screen.dart';
import '../games/checkers/checkers_screen.dart';
import '../games/walls/walls_screen.dart';
import '../games/orbs/orbs_screen.dart';
import '../games/xo/xo_screen.dart';

/// Bosh ekran: o'yinlar ro'yxati.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openXo(BuildContext context) async {
    final size = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('X-O'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 3),
            child: const ListTile(
              title: Text('3 × 3'),
              subtitle: Text('3 tasi bir qatorda — yutadi'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 10),
            child: const ListTile(
              title: Text('10 × 10'),
              subtitle: Text('5 tasi bir qatorda — yutadi'),
            ),
          ),
        ],
      ),
    );
    if (size == null || !context.mounted) return;
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => XoScreen(size: size)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyinim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.grid_3x3),
              title: const Text('X-O'),
              subtitle: const Text('Ikki kishi, bitta telefonda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openXo(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('Shashka'),
              subtitle: const Text('Ikki kishi, bitta telefonda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CheckersScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_boat),
              title: const Text('Dengiz jangi'),
              subtitle: const Text('Ikki kishi, bitta telefonda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BattleshipScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bubble_chart),
              title: const Text('Chain Burst'),
              subtitle: const Text('2–8 kishi, bitta telefonda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final s = await showChainSetup(context);
                if (s == null || !context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChainScreen(
                        players: s.players, rows: s.rows, cols: s.cols),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.blur_circular),
              title: const Text('Chain Burst: Sharlar'),
              subtitle: const Text('Bir kishi: fizikali boshqotirma'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OrbsScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fort),
              title: const Text('Escape the Walls'),
              subtitle: const Text('Bir kishi: devorlarni buzib qoching'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WallsScreen())),
            ),
          ),
        ],
      ),
    );
  }
}
