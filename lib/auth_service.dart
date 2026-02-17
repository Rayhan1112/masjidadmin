import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Web client ID for Google Sign-In
// Configure this in Firebase Console > Project Settings > Your apps > Web app
const String kWebClientId =
    '339125530903-031qieink56j76mgdepc0365bsecgdk2.apps.googleusercontent.com';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Centralized function to update user data in Firestore
  Future<void> _updateAdminData(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    final data = {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'type': 'superAdmin',
      'lastLogin': FieldValue.serverTimestamp(),
    };

    if (!snapshot.exists) {
      // If it's a new user, add the 'createdAt' timestamp.
      data['createdAt'] = FieldValue.serverTimestamp();
      return docRef.set(data);
    } else {
      return docRef.update(data);
    }
  }
  Future<User?> signUpWithPhonePassword(String phone, String password) async {
    try {
      // Create a dummy user in Firebase Auth to get a UID
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: '$phone@dummyemail.com', // Use a dummy email
        password: password,
      );
      User? user = userCredential.user;

      if (user != null) {
        // Store phone and password hash in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phone': phone,
          'password': password, // In a real app, hash this password
          'type': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
        return user;
      }
      return null;
    } catch (e) {
      print(e); // Handle errors appropriately
      return null;
    }
  }
  Future<User?> signInWithPhonePassword(String phone, String password) async {
    try {
      // 1. Find user by phone number in Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint("Phone Login: No user found with phone $phone");
        return null;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();
      final String? masjidId = userData['masjidId'];
      final String? userEmail = userData['email'];
      
      bool isPasswordValid = false;

      // 2. Check password in user document first
      if (userData.containsKey('password')) {
        isPasswordValid = userData['password'] == password;
      } 
      // 3. Fallback to check masjid's password if linked
      else if (masjidId != null) {
        final masjidDoc = await _firestore.collection('masjids').doc(masjidId).get();
        if (masjidDoc.exists) {
          isPasswordValid = (masjidDoc.data()?['password'] == password);
        }
      }

      if (!isPasswordValid) {
        debugPrint("Phone Login: Password mismatch for phone $phone");
        return null;
      }

      // 4. Determine email for Firebase Auth login
      // If we don't have an email in the user doc, use a dummy one
      final loginEmail = userEmail ?? "${phone.replaceAll(' ', '')}@masjid.com";

      // 5. Sign in or Create user in Firebase Auth
      User? user;
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: loginEmail,
          password: password,
        );
        user = userCredential.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // If user doesn't exist in Auth, but we verified in Firestore, create them
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: loginEmail,
            password: password,
          );
          user = userCredential.user;
        } else {
          rethrow;
        }
      }

      if (user != null) {
        // Sync timestamp
        await userDoc.reference.set({
          'lastLogin': FieldValue.serverTimestamp(),
          'uid': user.uid, // Ensure UID is synced
        }, SetOptions(merge: true));
        return user;
      }
      
      return null;
    } catch (e) {
      debugPrint("Phone Login Error: $e");
      return null;
    }
  }

  Future<User?> signInWithMasjidId(String mid, String password) async {
    try {
      // 1. Check if masjid exists with this ID and Password
      final doc = await _firestore.collection('masjids').doc(mid).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      if (data['password'] != password) return null;

      // 2. Sign in or Sign up into Firebase Auth using dummy email
      final email = '${mid.toLowerCase()}@masjid.com';
      UserCredential? userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      } catch (e) {
        // If user doesn't exist in Auth, create it
        userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }

      final user = userCredential.user;
      if (user != null) {
        // 3. Link this UID to the MasjidID in users collection
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'masjidId': mid,
          'type': 'masjidAdmin',
          'lastLogin': FieldValue.serverTimestamp(),
          'displayName': data['name'] ?? 'Masjid Admin',
        }, SetOptions(merge: true));
        return user;
      }
      return null;
    } catch (e) {
      debugPrint("Masjid Login Error: $e");
      return null;
    }
  }
  // Email/Password Sign Up
  Future<UserCredential?> signUpWithEmailPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      if (userCredential.user != null) {
        await _updateAdminData(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Email/Password Sign In
  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (userCredential.user != null) {
        await _updateAdminData(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // For web, try using popup-based sign-in with explicit client ID
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({
          'client_id': kWebClientId,
        });
        // Add scopes
        googleProvider
            .addScope('https://www.googleapis.com/auth/userinfo.email');
        googleProvider
            .addScope('https://www.googleapis.com/auth/userinfo.profile');

        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _updateAdminData(userCredential.user!);
        }
        return userCredential;
      }

      // For mobile apps
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _updateAdminData(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  /*
  // Phone Number Verification
  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // Phone Number Sign In
  Future<UserCredential?> signInWithPhoneNumber(
      String verificationId, String smsCode) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _updateAdminData(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
  */

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
