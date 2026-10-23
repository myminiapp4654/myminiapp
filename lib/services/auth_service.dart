import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    await _saveUserToFirestore(result.user!);
    return result.user;
  }

  Future<User?> signInAnonymously(String name, int age) async {
    final result = await _auth.signInAnonymously();
    await result.user!.updateDisplayName(name);
    await result.user!.reload();
    await _saveUserToFirestore(result.user!, name: name, age: age);
    return _auth.currentUser;
  }

  /// Ism o'zgarganda Firestore va Firebase Auth'dagi ismni birga yangilaydi.
  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({'name': name});
    await user.updateDisplayName(name);
    await user.reload();
  }

  /// Eski mehmon akkauntlarida displayName bo'sh — Firestore'dagi ismdan tiklaydi.
  Future<void> syncDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if ((user.displayName ?? '').isNotEmpty) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    final name = doc.data()?['name'] as String?;
    if (name == null || name.isEmpty) return;
    await user.updateDisplayName(name);
    await user.reload();
  }

  Future<void> _saveUserToFirestore(User user,
      {String? name, int? age}) async {
    final doc = _db.collection('users').doc(user.uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Mehmon',
        'age': age ?? 0,
        'photoUrl': user.photoURL,
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
