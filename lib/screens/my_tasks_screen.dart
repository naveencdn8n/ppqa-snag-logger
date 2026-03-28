import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/ppqa_app_bar.dart';
import '../widgets/snag_list_tile.dart';

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mySnags = state.getMySnags(state.currentUser?.id ?? '');

    return Scaffold(
      appBar: const PPQAAppBar(title: 'My Tasks', showBack: true),
      body: mySnags.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.task_alt,
                    size: 72,
                    color: Color(0xFFCED4DA),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You have no snags logged yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6C757D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Snags you log will appear here.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: const Color(0xFFECEFF4),
                  child: Text(
                    '${mySnags.length} snag${mySnags.length == 1 ? '' : 's'} assigned to you',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6C757D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: mySnags.length,
                    itemBuilder: (_, i) => SnagListTile(snag: mySnags[i]),
                  ),
                ),
              ],
            ),
    );
  }
}
