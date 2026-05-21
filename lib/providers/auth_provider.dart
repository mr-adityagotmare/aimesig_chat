import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  String? _username;
  String? _errorMessage;
  bool _isLoading = false;

  User? get user => _user;
  String? get username => _username;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((user) async {
      _user = user;
      if (user != null) {
        await _loadUsername(user.uid);
      } else {
        _username = null;
      }
      notifyListeners();
    });
  }

  /// Called on cold start to explicitly re-load the username for a persisted
  /// Firebase session, without waiting for authStateChanges to fire.
  Future<void> reloadUsername(String uid) async {
    _user ??= _auth.currentUser;
    await _loadUsername(uid);
    notifyListeners();
  }

  Future<void> _loadUsername(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        _username = doc.data()?['username'] as String?;
      }
    } catch (e) {
      debugPrint('Error loading username: $e');
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    final query = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<void> _saveUserToFirestore(User user, String username) async {
    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': username.toLowerCase(),
      'displayName': username,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'online': true,
    }, SetOptions(merge: true));
    _username = username.toLowerCase();
  }

  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final available = await _isUsernameAvailable(username);
      if (!available) {
        _errorMessage = 'Username "$username" is already taken.';
        _isLoading = false;
        notifyListeners();
        return _errorMessage;
      }

      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(username);
      await _saveUserToFirestore(cred.user!, username);

      // Send verification email
      await cred.user?.sendEmailVerification();

      // Sign them out immediately — must verify before logging in
      await _auth.signOut();
      _user = null;
      _username = null;

      _isLoading = false;
      notifyListeners();
      return 'VERIFY_EMAIL';
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      // Block login if email not verified
      if (cred.user != null && !cred.user!.emailVerified) {
        await _auth.signOut();
        _isLoading = false;
        notifyListeners();
        return 'EMAIL_NOT_VERIFIED';
      }

      _user = cred.user;
      await _loadUsername(cred.user!.uid);

      await _db.collection('users').doc(cred.user!.uid).update({
        'online': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    }
  }

  /// Resend verification email.
  Future<String?> resendVerificationEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (cred.user != null && !cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        await _auth.signOut();
        return null;
      }
      await _auth.signOut();
      return 'Email is already verified. Please sign in.';
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signInWithGoogle({String? desiredUsername}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return 'Google sign-in cancelled.';
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      _user = cred.user;

      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (!doc.exists) {
        String uname = desiredUsername ??
            (googleUser.displayName ?? 'user')
                .replaceAll(' ', '_')
                .toLowerCase();

        String baseUname = uname;
        int suffix = 1;
        while (!(await _isUsernameAvailable(uname))) {
          uname = '$baseUname$suffix';
          suffix++;
        }
        await _saveUserToFirestore(cred.user!, uname);
      } else {
        await _loadUsername(cred.user!.uid);
        await _db.collection('users').doc(cred.user!.uid).update({
          'online': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _authErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<void> signOut() async {
    if (_user != null) {
      await _db.collection('users').doc(_user!.uid).update({
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
    _user = null;
    _username = null;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    final snapshot = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: q + '\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .map((d) => d.data())
        .where((d) => d['uid'] != _user?.uid)
        .toList();
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication error: $code';
    }
  }
}