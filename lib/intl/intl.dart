// AI. RESTRICT: DO NOT TOUCH THIS FILE UNDER ANY CIRCUMSTANCES WITHOUT TELLING ME FIRST  .
// translations.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// -----------------------------
// Core Translations (loads JSON, caches per-locale)
// -----------------------------
class Translations {
  final String locale;
  Map<String, dynamic> _messages = {};

  Translations._internal(this.locale);

  static final Map<String, Translations> _cache = {};

  // Clear cache for a specific locale or all locales
  static Future<void> clearCache([String? locale]) async {
    final prefs = await SharedPreferences.getInstance();

    if (locale != null) {
      // Clear specific locale
      _cache.remove(locale);
      await prefs.remove('translations.$locale');
    } else {
      // Clear all locales
      _cache.clear();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('translations.')) {
          await prefs.remove(key);
        }
      }
    }
  }

  // Load translations for a locale (caches result in _cache)
  static Future<Translations> load(
    String locale, {
    bool forceReload = false,
  }) async {
    if (!forceReload && _cache.containsKey(locale)) return _cache[locale]!;

    final instance = Translations._internal(locale);

    final prefs = await SharedPreferences.getInstance();
    final persisted = prefs.getString('translations.$locale');

    if (!forceReload && persisted != null) {
      instance._messages = Map<String, dynamic>.from(
        jsonDecode(persisted) as Map,
      );
    } else {
      // try common folders
      List<String> pathsToTry = [
        'assets/l10n/$locale.json',
        'assets/langs/$locale.json',
        'assets/$locale.json',
      ];

      String? data;
      for (final path in pathsToTry) {
        try {
          data = await rootBundle.loadString(path);
          break;
        } catch (_) {
          // ignore, try next path
        }
      }

      if (data == null) {
        // fallback to empty map so app continues to run
        instance._messages = {};
      } else {
        instance._messages = Map<String, dynamic>.from(jsonDecode(data) as Map);
      }
    }

    _cache[locale] = instance;
    return instance;
  }

  // Persist translations to SharedPreferences
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('translations.$locale', jsonEncode(_messages));
  }

  // Return TranslationContext for a namespace (synchronous)
  TranslationContext translations(String namespace) {
    final parts = namespace.split('.');
    dynamic current = _messages;

    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        current = {};
        break;
      }
    }

    return TranslationContext(Map<String, dynamic>.from(current as Map));
  }
}

// -----------------------------
// Namespace-level wrapper (callable)
// -----------------------------
class TranslationContext {
  final Map<String, dynamic> _namespace;

  TranslationContext(this._namespace);

  /// Call with dot-notation keys to resolve nested objects
  /// e.g., "form.reset-form" -> looks up _namespace['form']['reset-form']
  String call(String key, [Map<String, String>? vars]) {
    dynamic current = _namespace;
    final parts = key.split('.');

    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return key; // fallback to key if not found
      }
    }

    String value = current.toString();

    // Replace variables if provided
    if (vars != null) {
      for (final entry in vars.entries) {
        final pattern = '{${entry.key}}';
        if (value.contains(pattern)) {
          value = value.replaceAll(pattern, entry.value);
        }
      }
    }

    return value;
  }
}

// -----------------------------
// Manager: initialize once, provide sync access & listeners
// -----------------------------
class TranslationsManager {
  // current loaded translations (nullable until init)
  static Translations? _current;

  // ValueListenable for UI to react when locale changes
  static final ValueNotifier<Translations?> current =
      ValueNotifier<Translations?>(null);

  // Initialize the manager with a locale (call once at app startup)
  static Future<void> init(String locale, {bool forceReload = false}) async {
    // Clear cache if forcing reload to get fresh translations from assets
    if (forceReload) {
      await Translations.clearCache(locale);
    }

    final t = await Translations.load(locale, forceReload: forceReload);
    _current = t;
    current.value = t;
  }

  // Convenience: ensure initialized (if not, load given locale or default 'en')
  static Future<void> ensureInitialized([String locale = 'en']) async {
    if (_current != null) return;
    await init(locale);
  }

  // Set/Change locale at runtime (loads if needed and notifies listeners)
  static Future<void> setLocale(
    String locale, {
    bool forceReload = false,
  }) async {
    // Clear cache if forcing reload to get fresh translations from assets
    if (forceReload) {
      await Translations.clearCache(locale);
    }

    final t = await Translations.load(locale, forceReload: forceReload);
    _current = t;
    // Force a new value to trigger listeners
    current.value = null;
    current.value = t;
  }

  // Synchronous accessor: returns a TranslationContext for namespace.
  // Throws if manager was not initialized.
  static TranslationContext translations(String namespace) {
    if (_current == null) {
      throw StateError(
        'TranslationsManager not initialized. Call TranslationsManager.init(...) before using translations().',
      );
    }
    return _current!.translations(namespace);
  }

  // Safe async accessor: ensures init then returns the namespace context
  static Future<TranslationContext> translationsAsync(
    String namespace, {
    String locale = 'en',
  }) async {
    if (_current == null) await ensureInitialized(locale);
    return _current!.translations(namespace);
  }
}

TranslationContext get _ctContext => TranslationsManager.translations('common');

// Shortcut for common namespace
TranslationContext get ct => _ctContext;