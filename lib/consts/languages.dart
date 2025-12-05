class LanguageConstants {
  // Unified language data with both emoji flags and SVG flag codes
  // convId maps to the database language.id
  static const Map<String, Map<String, String>> languages = {
    'en': {'name': 'English', 'flag': '🇺🇸', 'flagCode': 'us', 'convId': '1'},
    'th': {'name': 'ไทย', 'flag': '🇹🇭', 'flagCode': 'th', 'convId': '2'},
    'es-ES': {
      'name': 'Español (España)',
      'flag': '🇪🇸',
      'flagCode': 'es',
      'convId': '3',
    },
    'fr-FR': {
      'name': 'Français (France)',
      'flag': '🇫🇷',
      'flagCode': 'fr',
      'convId': '5',
    },
    'pt-PT': {
      'name': 'Português (Portugal)',
      'flag': '🇵🇹',
      'flagCode': 'pt',
      'convId': '7',
    },
    'zh-CN': {
      'name': '中文 (简体, 中国)',
      'flag': '🇨🇳',
      'flagCode': 'cn',
      'convId': '9',
    },
    'ar-SA': {
      'name': 'العربية (السعودية)',
      'flag': '🇸🇦',
      'flagCode': 'sa',
      'convId': '11',
    },
    'de-DE': {
      'name': 'Deutsch (Deutschland)',
      'flag': '🇩🇪',
      'flagCode': 'de',
      'convId': '13',
    },
    'ja': {'name': '日本語', 'flag': '🇯🇵', 'flagCode': 'jp', 'convId': '15'},
    'ko': {'name': '한국어', 'flag': '🇰🇷', 'flagCode': 'kr', 'convId': '16'},
    'ru': {'name': 'Русский', 'flag': '🇷🇺', 'flagCode': 'ru', 'convId': '17'},
    'it': {
      'name': 'Italiano',
      'flag': '🇮🇹',
      'flagCode': 'it',
      'convId': '18',
    },
    'hi': {'name': 'हिन्दी', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '19'},
    'bn': {'name': 'বাংলা', 'flag': '🇧🇩', 'flagCode': 'bd', 'convId': '20'},
    'ms': {
      'name': 'Bahasa Melayu',
      'flag': '🇲🇾',
      'flagCode': 'my',
      'convId': '21',
    },
    'vi': {
      'name': 'Tiếng Việt',
      'flag': '🇻🇳',
      'flagCode': 'vn',
      'convId': '22',
    },
    'id': {
      'name': 'Bahasa Indonesia',
      'flag': '🇮🇩',
      'flagCode': 'id',
      'convId': '23',
    },
    'tr': {'name': 'Türkçe', 'flag': '🇹🇷', 'flagCode': 'tr', 'convId': '24'},
    'pl': {'name': 'Polski', 'flag': '🇵🇱', 'flagCode': 'pl', 'convId': '25'},
    'nl': {
      'name': 'Nederlands',
      'flag': '🇳🇱',
      'flagCode': 'nl',
      'convId': '26',
    },
    'sv': {'name': 'Svenska', 'flag': '🇸🇪', 'flagCode': 'se', 'convId': '27'},
    'no': {'name': 'Norsk', 'flag': '🇳🇴', 'flagCode': 'no', 'convId': '28'},
    'fi': {'name': 'Suomi', 'flag': '🇫🇮', 'flagCode': 'fi', 'convId': '29'},
    'da': {'name': 'Dansk', 'flag': '🇩🇰', 'flagCode': 'dk', 'convId': '30'},
    'el': {
      'name': 'Ελληνικά',
      'flag': '🇬🇷',
      'flagCode': 'gr',
      'convId': '31',
    },
    'he': {'name': 'עברית', 'flag': '🇮🇱', 'flagCode': 'il', 'convId': '32'},
    'ro': {'name': 'Română', 'flag': '🇷🇴', 'flagCode': 'ro', 'convId': '33'},
    'hu': {'name': 'Magyar', 'flag': '🇭🇺', 'flagCode': 'hu', 'convId': '34'},
    'cs': {'name': 'Čeština', 'flag': '🇨🇿', 'flagCode': 'cz', 'convId': '35'},
    'sk': {
      'name': 'Slovenčina',
      'flag': '🇸🇰',
      'flagCode': 'sk',
      'convId': '36',
    },
    'bg': {
      'name': 'Български',
      'flag': '🇧🇬',
      'flagCode': 'bg',
      'convId': '37',
    },
    'uk': {
      'name': 'Українська',
      'flag': '🇺🇦',
      'flagCode': 'ua',
      'convId': '38',
    },
    'hr': {
      'name': 'Hrvatski',
      'flag': '🇭🇷',
      'flagCode': 'hr',
      'convId': '39',
    },
    'sr': {'name': 'Српски', 'flag': '🇷🇸', 'flagCode': 'rs', 'convId': '40'},
    'sl': {
      'name': 'Slovenščina',
      'flag': '🇸🇮',
      'flagCode': 'si',
      'convId': '41',
    },
    'lt': {
      'name': 'Lietuvių',
      'flag': '🇱🇹',
      'flagCode': 'lt',
      'convId': '42',
    },
    'lv': {
      'name': 'Latviešu',
      'flag': '🇱🇻',
      'flagCode': 'lv',
      'convId': '43',
    },
    'et': {'name': 'Eesti', 'flag': '🇪🇪', 'flagCode': 'ee', 'convId': '44'},
    'fa': {'name': 'فارسی', 'flag': '🇮🇷', 'flagCode': 'ir', 'convId': '45'},
    'ta': {'name': 'தமிழ்', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '46'},
    'te': {'name': 'తెలుగు', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '47'},
    'kn': {'name': 'ಕನ್ನಡ', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '48'},
    'ml': {'name': 'മലയാളം', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '49'},
    'mr': {'name': 'मराठी', 'flag': '🇮🇳', 'flagCode': 'in', 'convId': '50'},
    'ur': {'name': 'اردو', 'flag': '🇵🇰', 'flagCode': 'pk', 'convId': '51'},
    'sw': {
      'name': 'Kiswahili',
      'flag': '🇹🇿',
      'flagCode': 'tz',
      'convId': '52',
    },
    'tl': {
      'name': 'Filipino',
      'flag': '🇵🇭',
      'flagCode': 'ph',
      'convId': '53',
    },
    'zu': {'name': 'isiZulu', 'flag': '🇿🇦', 'flagCode': 'za', 'convId': '54'},
    'xh': {
      'name': 'isiXhosa',
      'flag': '🇿🇦',
      'flagCode': 'za',
      'convId': '55',
    },
    'st': {'name': 'Sesotho', 'flag': '🇿🇦', 'flagCode': 'za', 'convId': '56'},
    'so': {
      'name': 'Soomaali',
      'flag': '🇸🇴',
      'flagCode': 'so',
      'convId': '57',
    },
    'yo': {'name': 'Yorùbá', 'flag': '🇳🇬', 'flagCode': 'ng', 'convId': '58'},
    'am': {'name': 'አማርኛ', 'flag': '🇪🇹', 'flagCode': 'et', 'convId': '59'},
    // Language variants
    'es-MX': {
      'name': 'Español (México)',
      'flag': '🇲🇽',
      'flagCode': 'mx',
      'convId': '4',
    },
    'fr-CA': {
      'name': 'Français (Canada)',
      'flag': '🇨🇦',
      'flagCode': 'ca',
      'convId': '6',
    },
    'pt-BR': {
      'name': 'Português (Brasil)',
      'flag': '🇧🇷',
      'flagCode': 'br',
      'convId': '8',
    },
    'zh-TW': {
      'name': '中文 (繁體, 台灣)',
      'flag': '🇹🇼',
      'flagCode': 'tw',
      'convId': '10',
    },
    'ar-EG': {
      'name': 'العربية (مصر)',
      'flag': '🇪🇬',
      'flagCode': 'eg',
      'convId': '12',
    },
    'de-AT': {
      'name': 'Deutsch (Österreich)',
      'flag': '🇦🇹',
      'flagCode': 'at',
      'convId': '14',
    },
  };

  // Map of database language ID (convId) to flag code (icon)
  static final Map<String, String> _iconDict = {
    '1': 'us', // en
    '2': 'th', // th
    '3': 'es', // es
    '5': 'fr', // fr
    '7': 'pt', // pt
    '9': 'cn', // zh
    '11': 'sa', // ar
    '13': 'de', // de
    '15': 'jp', // ja
    '16': 'kr', // ko
    '17': 'ru', // ru
    '18': 'it', // it
    '19': 'in', // hi
    '20': 'bd', // bn
    '21': 'my', // ms
    '22': 'vn', // vi
    '23': 'id', // id
    '24': 'tr', // tr
    '25': 'pl', // pl
    '26': 'nl', // nl
    '27': 'se', // sv
    '28': 'no', // no
    '29': 'fi', // fi
    '30': 'dk', // da
    '31': 'gr', // el
    '32': 'il', // he
    '33': 'ro', // ro
    '34': 'hu', // hu
    '35': 'cz', // cs
    '36': 'sk', // sk
    '37': 'bg', // bg
    '38': 'ua', // uk
    '39': 'hr', // hr
    '40': 'rs', // sr
    '41': 'si', // sl
    '42': 'lt', // lt
    '43': 'lv', // lv
    '44': 'ee', // et
    '45': 'ir', // fa
    '46': 'in', // ta
    '47': 'in', // te
    '48': 'in', // kn
    '49': 'in', // ml
    '50': 'in', // mr
    '51': 'pk', // ur
    '52': 'tz', // sw
    '53': 'ph', // tl
    '54': 'za', // zu
    '55': 'za', // xh
    '56': 'za', // st
    '57': 'so', // so
    '58': 'ng', // yo
    '59': 'et', // am
    '4': 'mx', // es-MX
    '6': 'ca', // fr-CA
    '8': 'br', // pt-BR
    '10': 'tw', // zh-TW
    '12': 'eg', // ar-EG
    '14': 'at', // de-AT
  };

  static const List<String> noSpacingLangs = [
    // Major / common ones
    'th', 'th-th',
    'lo', 'lo-la',
    'km', 'km-kh',
    'my', 'my-mm',
    'zh', 'zh-cn', 'zh-sg', 'zh-hans',
    'zh-tw', 'zh-hk', 'zh-mo', 'zh-hant',
    'zh-hant-tw', 'zh-hant-hk', 'zh-hant-mo',
    'ja', 'ja-jp',
    'bo', 'bo-cn', 'bo-in',
    'dz', 'dz-bt',
    'he', 'he-il', // Hebrew
    'ar', 'ar-sa', 'ar-eg', 'ar-ae', // Arabic
    'hi', 'hi-in', // Hindi
    // Additional ones / variants identified
    'gan', // Gan Chinese (a Sinitic language) :contentReference[oaicite:0]{index=0}
    'yue', // Cantonese / Yue Chinese (often no spaces) :contentReference[oaicite:1]{index=1}
    'wuu', // Wu Chinese (dialect) :contentReference[oaicite:2]{index=2}
    // Southeast Asian script-based / minority
    'nod',
    'nod-th', // Northern Thai / Lanna variant :contentReference[oaicite:3]{index=3}
    'shn',
    'shn-mm', // Shan language (Myanmar) – script often no word spaces :contentReference[oaicite:4]{index=4}
    'khb', // Tai Lue (New Tai Lue) – variable spacing :contentReference[oaicite:5]{index=5}
    'tdd', // Tai Nua – similar spacing issues :contentReference[oaicite:6]{index=6}
    'jv',
    'jv-id', // Javanese script (traditional) – often no spaces in classical form :contentReference[oaicite:7]{index=7}
  ];

  // Get icon (flag code) based on language ID
  static String getIcon(int languageId) {
    final iconCode = _iconDict[languageId.toString()];
    if (iconCode == null) {
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('⚠️  [LanguageConstants.getIcon] ICON NOT FOUND');
      print('═══════════════════════════════════════════════════════════════');
      print('Requested Language ID: $languageId');
      print('');
      print('DIAGNOSIS:');
      print('  ❌ Language ID "$languageId" is NOT present in _iconDict');
      print('');

      // Check if language exists in languages map but missing from _iconDict
      final matchingLanguages = languages.entries.where((entry) {
        final convId = entry.value['convId'];
        return convId == languageId.toString();
      }).toList();

      if (matchingLanguages.isNotEmpty) {
        print('FOUND IN languages MAP:');
        for (var entry in matchingLanguages) {
          final code = entry.key;
          final name = entry.value['name'];
          final flagCode = entry.value['flagCode'];
          final convId = entry.value['convId'];
          print('  ✓ Code: "$code"');
          print('    Name: $name');
          print('    Flag Code: $flagCode');
          print('    ConvId: $convId');
          print(
            '    → NEEDS TO BE ADDED TO _iconDict: \'$convId\': \'$flagCode\'',
          );
        }
        print('');
      } else {
        print('NOT FOUND IN languages MAP:');
        print(
          '  ❌ No language with convId="$languageId" exists in languages map',
        );
        print('  → Language may not be in the database or needs to be added');
        print('');
      }

      print('CURRENT _iconDict ENTRIES (${_iconDict.length} total):');
      final sortedKeys = _iconDict.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      for (var key in sortedKeys) {
        print('  ID $key → flagCode "${_iconDict[key]}"');
      }
      print('');

      print('MISSING FROM _iconDict:');
      print('  Add this entry to fix:');
      print(
        '    \'$languageId\': \'un\',  // TODO: Replace \'un\' with correct flag code',
      );
      print('');

      print('RECOMMENDED FIX:');
      if (matchingLanguages.isNotEmpty) {
        final flagCode = matchingLanguages.first.value['flagCode'] ?? 'un';
        print('  1. Add to _iconDict: \'$languageId\': \'$flagCode\',');
        print(
          '  2. Verify the flag code "$flagCode" exists in assets/flags/4x3/',
        );
      } else {
        print(
          '  1. Verify language ID $languageId exists in database (init.sql)',
        );
        print('  2. Add language entry to languages map if missing');
        print('  3. Add corresponding entry to _iconDict');
      }
      print('═══════════════════════════════════════════════════════════════');
      print('');
      return 'un';
    }
    return iconCode;
  }

  // Helper method to get language name
  static String getLanguageName(String languageCode) {
    if (languages.containsKey(languageCode)) {
      return languages[languageCode]!['name']!;
    }
    return languageCode;
  }

  // Helper method to get emoji flag
  static String getEmojiFlag(String languageCode) {
    if (languages.containsKey(languageCode)) {
      return languages[languageCode]!['flag']!;
    }
    return '🌐'; // Fallback flag
  }

  // Helper method to get SVG flag code
  static String getFlagCode(String languageCode) {
    if (languages.containsKey(languageCode)) {
      return languages[languageCode]!['flagCode']!;
    }
    return 'un'; // Fallback flag code
  }

  // Helper method to get database ID (convId)
  static String? getConvId(String languageCode) {
    if (languages.containsKey(languageCode)) {
      return languages[languageCode]!['convId'];
    }
    return null;
  }

  // Helper method to get language code from database ID (convId)
  static String? getLanguageCodeFromId(int languageId) {
    final idString = languageId.toString();
    for (final entry in languages.entries) {
      if (entry.value['convId'] == idString) {
        return entry.key;
      }
    }
    return null;
  }

  // Helper method to get flag path for SVG assets
  static String getFlagPath(String languageCode) {
    final flagCode = getFlagCode(languageCode);
    return 'assets/flags/4x3/$flagCode.svg';
  }

  // Get all available language codes
  static List<String> getAvailableLanguageCodes() {
    return languages.keys.toList();
  }

  // Get languages as a simple map for backward compatibility
  static Map<String, Map<String, String>> getLanguagesForSelector() {
    return languages.map(
      (key, value) =>
          MapEntry(key, {'name': value['name']!, 'flag': value['flag']!}),
    );
  }

  /// Get TTS language code for a given language code
  /// Returns the appropriate locale code for text-to-speech engines
  /// If the language code already has a region (e.g., 'zh-CN'), uses it directly
  /// Otherwise, maps to the appropriate TTS locale (e.g., 'en' -> 'en-US')
  static String getTtsLanguageCode(String languageCode) {
    // Normalize language code (remove region if present for lookup)
    final normalizedCode = languageCode.contains('-')
        ? languageCode.split('-').first
        : languageCode;

    // Check if we have an entry with region code already
    if (languages.containsKey(languageCode)) {
      // Use the language code as-is if it's already in the map
      return languageCode;
    }

    // Check if we have the normalized code
    if (languages.containsKey(normalizedCode)) {
      // Map normalized codes to TTS locale codes
      const ttsLocaleMap = {
        'en': 'en-US',
        'th': 'th-TH',
        'zh': 'zh-CN',
        'ru': 'ru-RU',
        'ko': 'ko-KR',
        'ja': 'ja-JP',
        'fr': 'fr-FR',
        'es': 'es-ES',
        'de': 'de-DE',
        'vi': 'vi-VN',
        'ar': 'ar-SA',
        'pt': 'pt-BR',
        'id': 'id-ID',
        'it': 'it-IT',
        'hi': 'hi-IN',
        'bn': 'bn-BD',
        'ms': 'ms-MY',
        'tr': 'tr-TR',
        'pl': 'pl-PL',
        'nl': 'nl-NL',
        'sv': 'sv-SE',
        'no': 'no-NO',
        'fi': 'fi-FI',
        'da': 'da-DK',
        'el': 'el-GR',
        'he': 'he-IL',
        'ro': 'ro-RO',
        'hu': 'hu-HU',
        'cs': 'cs-CZ',
        'sk': 'sk-SK',
        'bg': 'bg-BG',
        'uk': 'uk-UA',
        'hr': 'hr-HR',
        'sr': 'sr-RS',
        'sl': 'sl-SI',
        'lt': 'lt-LT',
        'lv': 'lv-LV',
        'et': 'et-EE',
        'fa': 'fa-IR',
        'ta': 'ta-IN',
        'te': 'te-IN',
        'kn': 'kn-IN',
        'ml': 'ml-IN',
        'mr': 'mr-IN',
        'ur': 'ur-PK',
        'sw': 'sw-TZ',
        'tl': 'tl-PH',
        'zu': 'zu-ZA',
        'xh': 'xh-ZA',
        'st': 'st-ZA',
        'so': 'so-SO',
        'yo': 'yo-NG',
        'am': 'am-ET',
      };

      return ttsLocaleMap[normalizedCode] ?? 'en-US';
    }

    // Fallback to en-US if language not found
    return 'en-US';
  }
}
