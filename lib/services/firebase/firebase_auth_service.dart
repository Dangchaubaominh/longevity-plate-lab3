import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app_failure.dart';
import '../service_interfaces.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService();

  final _auth = FirebaseAuth.instance;
  Future<void>? _googleInit;

  // initialize() chỉ được gọi một lần trong vòng đời app.
  Future<void> _ensureGoogleInit() =>
      _googleInit ??= GoogleSignIn.instance.initialize();

  AppUser? _map(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName,
          email: user.email,
        );

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleInit();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AppFailure('google_missing_id_token');
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // Mất mạng lúc chọn tài khoản cũng trả về canceled, nên phải kiểm tra mạng.
        if (!await _hasNetwork()) {
          throw const AppFailure('network-request-failed');
        }
        throw const SignInCancelled();
      }
      throw AppFailure('google_${e.code.name}', e.description);
    } on FirebaseAuthException catch (e) {
      throw AppFailure(e.code, e.message);
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final addresses = await InternetAddress.lookup(
        'identitytoolkit.googleapis.com',
      ).timeout(const Duration(seconds: 3));
      return addresses.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  Future<String?> idToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } on FirebaseAuthException catch (e) {
      // Token hết hạn mà mất mạng thì không làm mới được, ví dụ network-request-failed.
      throw AppFailure(e.code, e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureGoogleInit();
    // Đăng xuất cả Google để lần sau được chọn lại tài khoản.
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
