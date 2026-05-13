import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates and persists a stable device ID that survives:
///   - App restarts
///   - Phone reboots
///   - Network / IP changes
///   - LAN / Wi-Fi switches
///
/// The ID is: SHA-256( name + salt )  → hex string (first 32 chars)
/// The salt is a random UUID stored once in SharedPreferences.
/// As long as the user keeps the same name on the same device, the ID never changes.
/// If the user explicitly changes their name a *new* ID is generated and stored.
class DeviceId {
  static const _keyId   = 'device_id';
  static const _keySalt = 'device_id_salt';
  static const _keyName = 'device_id_name'; // name that was used when the ID was created

  /// Returns the stored device ID, or null if none exists yet.
  static Future<String?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyId);
  }

  /// Generates (or re-uses) a stable ID for [name].
  ///
  /// • First call  → creates a random salt, hashes name+salt, saves everything.
  /// • Same name   → returns the already-stored ID (salt is reused).
  /// • New name    → generates a brand-new salt + ID so old chats stay intact
  ///                 and the new identity is truly distinct.
  static Future<String> generate(String name) async {
    final prefs = await SharedPreferences.getInstance();

    final storedId   = prefs.getString(_keyId);
    final storedSalt = prefs.getString(_keySalt);
    final storedName = prefs.getString(_keyName);

    // Re-use the existing ID if the name hasn't changed.
    if (storedId != null && storedSalt != null && storedName == name) {
      return storedId;
    }

    // New name (or first-ever launch) → create a fresh salt + ID.
    final salt = const Uuid().v4();           // random, stored permanently
    final id   = _hash(name, salt);           // deterministic from this point on

    await prefs.setString(_keyId,   id);
    await prefs.setString(_keySalt, salt);
    await prefs.setString(_keyName, name);

    return id;
  }

  /// Recomputes the ID from the stored salt for the given name.
  /// Use this after a name change to check what the new ID would be
  /// *before* committing – generally you just call [generate] directly.
  static Future<String> recompute(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final salt  = prefs.getString(_keySalt) ?? const Uuid().v4();
    return _hash(name, salt);
  }

  // ── private helpers ────────────────────────────────────────────────────────

  static String _hash(String name, String salt) {
    final bytes  = utf8.encode('$name:$salt');
    final digest = sha256.convert(bytes);
    // Use the first 32 hex characters (128-bit) – compact yet collision-proof.
    return digest.toString().substring(0, 32);
  }
}