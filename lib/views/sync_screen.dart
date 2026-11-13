import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_services.dart';
import '../services/sync/sync_engine.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final engine = context.read<AppServices>().sync;
    if (engine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đồng bộ')),
        body: const Center(child: Text('Bản cài này đang lưu trên thiết bị.')),
      );
    }
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => _View(engine: engine),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.engine});
  final SyncEngine engine;
  @override
  Widget build(BuildContext context) {
    final uid = engine.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Đồng bộ dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            engine.busy
                ? 'Đang đồng bộ…'
                : engine.pendingCount == 0
                ? 'Dữ liệu đã đồng bộ'
                : '${engine.pendingCount} mục đang chờ',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bữa ăn và kế hoạch được lưu trên thiết bị trước. Có mạng, ứng dụng gửi thay đổi lên tài khoản của bạn.',
          ),
          if (engine.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa đồng bộ được (${engine.error}). Dữ liệu đã lưu trên máy vẫn được giữ.',
              ),
            ),
          FilledButton.icon(
            onPressed: engine.busy ? null : engine.retryAll,
            icon: const Icon(Icons.sync),
            label: const Text('Đồng bộ lại'),
          ),
          if (uid != null)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: engine.store.pending(uid),
              builder: (context, snapshot) => Column(
                children: [
                  for (final op in snapshot.data ?? <Map<String, dynamic>>[])
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${op['kind']} · ${op['record_id']}'),
                            Text('Trạng thái: ${op['state']}'),
                            if (op['state'] == 'conflict') ...[
                              const Text(
                                'Bản trên máy và trên tài khoản đã thay đổi. Chọn bản muốn giữ.',
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _resolve(context, uid, op, true),
                                    child: const Text('Giữ bản trên máy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        _resolve(context, uid, op, false),
                                    child: const Text(
                                      'Dùng bản trên tài khoản',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          FutureBuilder<List<String>>(
            future: engine.photoConflicts(),
            builder: (context, snapshot) => Column(
              children: [
                for (final id in snapshot.data ?? <String>[])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('Ảnh bữa ăn $id có xung đột.'),
                          const Text(
                            'Bữa ăn đã thay đổi trên tài khoản. Chọn ảnh muốn giữ.',
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => _photo(context, id, true),
                                child: const Text('Giữ ảnh trên máy'),
                              ),
                              TextButton(
                                onPressed: () => _photo(context, id, false),
                                child: const Text('Dùng ảnh trên tài khoản'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(
    BuildContext context,
    String uid,
    Map<String, dynamic> op,
    bool keep,
  ) async {
    try {
      await engine.store.resolve(
        uid,
        op['kind'] as String,
        op['record_id'] as String,
        keepLocal: keep,
      );
      await engine.synchronize();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa xử lý được xung đột. Hãy đồng bộ rồi thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _photo(BuildContext context, String id, bool keep) async {
    try {
      await engine.resolvePhoto(id, keepLocal: keep);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa xử lý được ảnh. Hãy thử lại.')),
        );
      }
    }
  }
}
