import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';


import '../app_failure.dart';
import '../service_interfaces.dart';

class FirebaseReportStorageService implements ReportStorageService {
  FirebaseReportStorageService(this._faults) {
    // Mặc định SDK thử lại 10 phút, mất mạng thì người dùng phải chờ quá lâu.
    _storage.setMaxUploadRetryTime(const Duration(seconds: 30));
    _storage.setMaxOperationRetryTime(const Duration(seconds: 15));
  }

  final FaultInjector _faults;
  final _storage = FirebaseStorage.instance;

  @override
  Stream<UploadProgress> upload({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async* {
    _faults.check(FaultPoint.uploadReport);
    final ref = _storage.ref('reports/$uid/$fileName');
    final task = ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    try {
      await for (final snapshot in task.snapshotEvents) {
        if (snapshot.state == TaskState.running && snapshot.totalBytes > 0) {
          yield UploadProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
        if (snapshot.state == TaskState.success) break;
      }
      await task;
      yield UploadProgress(1, downloadUrl: await ref.getDownloadURL());
    } on FirebaseException catch (e) {
      throw AppFailure(e.code, e.message);
    }
  }

  @override
  Future<String> probeForeignReport() async {
    try {
      await _storage.ref('reports/uid-khac-de-kiem-thu/khong-co.pdf').getData();
      return 'allowed';
    } on FirebaseException catch (e) {
      return e.code;
    }
  }
}
