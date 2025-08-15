class FixLanguageNomenclatureAndPopulateLanguages < ActiveRecord::Migration[7.1]
  def up
    # Fix existing language nomenclature in agent_templates (pt-BR -> pt_BR, etc.)
    execute <<-SQL
      UPDATE agent_templates
      SET language = REPLACE(language, '-', '_')
      WHERE language LIKE '%-%'
    SQL

    # Populate supported_languages table with common languages
    languages = [
      { code: 'en', name: 'English', native_name: 'English', enabled: true },
      { code: 'pt_BR', name: 'Portuguese (Brazil)', native_name: 'Português (Brasil)', enabled: true },
      { code: 'pt', name: 'Portuguese', native_name: 'Português', enabled: true },
      { code: 'es', name: 'Spanish', native_name: 'Español', enabled: true },
      { code: 'es_MX', name: 'Spanish (Mexico)', native_name: 'Español (México)', enabled: true },
      { code: 'fr', name: 'French', native_name: 'Français', enabled: true },
      { code: 'fr_CA', name: 'French (Canada)', native_name: 'Français (Canada)', enabled: true },
      { code: 'de', name: 'German', native_name: 'Deutsch', enabled: true },
      { code: 'it', name: 'Italian', native_name: 'Italiano', enabled: true },
      { code: 'ru', name: 'Russian', native_name: 'Русский', enabled: true },
      { code: 'zh_CN', name: 'Chinese (Simplified)', native_name: '简体中文', enabled: true },
      { code: 'zh_TW', name: 'Chinese (Traditional)', native_name: '繁體中文', enabled: true },
      { code: 'ja', name: 'Japanese', native_name: '日本語', enabled: true },
      { code: 'ko', name: 'Korean', native_name: '한국어', enabled: true },
      { code: 'ar', name: 'Arabic', native_name: 'العربية', enabled: true },
      { code: 'hi', name: 'Hindi', native_name: 'हिन्दी', enabled: true },
      { code: 'th', name: 'Thai', native_name: 'ไทย', enabled: true },
      { code: 'vi', name: 'Vietnamese', native_name: 'Tiếng Việt', enabled: true },
      { code: 'id', name: 'Indonesian', native_name: 'Bahasa Indonesia', enabled: true },
      { code: 'ms', name: 'Malay', native_name: 'Bahasa Melayu', enabled: true },
      { code: 'nl', name: 'Dutch', native_name: 'Nederlands', enabled: true },
      { code: 'sv', name: 'Swedish', native_name: 'Svenska', enabled: true },
      { code: 'no', name: 'Norwegian', native_name: 'Norsk', enabled: true },
      { code: 'da', name: 'Danish', native_name: 'Dansk', enabled: true },
      { code: 'fi', name: 'Finnish', native_name: 'Suomi', enabled: true },
      { code: 'pl', name: 'Polish', native_name: 'Polski', enabled: true },
      { code: 'cs', name: 'Czech', native_name: 'Čeština', enabled: true },
      { code: 'sk', name: 'Slovak', native_name: 'Slovenčina', enabled: true },
      { code: 'hu', name: 'Hungarian', native_name: 'Magyar', enabled: true },
      { code: 'ro', name: 'Romanian', native_name: 'Română', enabled: true },
      { code: 'bg', name: 'Bulgarian', native_name: 'Български', enabled: true },
      { code: 'hr', name: 'Croatian', native_name: 'Hrvatski', enabled: true },
      { code: 'sr', name: 'Serbian', native_name: 'Српски', enabled: true },
      { code: 'sl', name: 'Slovenian', native_name: 'Slovenščina', enabled: true },
      { code: 'et', name: 'Estonian', native_name: 'Eesti', enabled: true },
      { code: 'lv', name: 'Latvian', native_name: 'Latviešu', enabled: true },
      { code: 'lt', name: 'Lithuanian', native_name: 'Lietuvių', enabled: true },
      { code: 'el', name: 'Greek', native_name: 'Ελληνικά', enabled: true },
      { code: 'tr', name: 'Turkish', native_name: 'Türkçe', enabled: true },
      { code: 'he', name: 'Hebrew', native_name: 'עברית', enabled: true },
      { code: 'fa', name: 'Persian', native_name: 'فارسی', enabled: true },
      { code: 'ur', name: 'Urdu', native_name: 'اردو', enabled: true },
      { code: 'bn', name: 'Bengali', native_name: 'বাংলা', enabled: true },
      { code: 'ta', name: 'Tamil', native_name: 'தமிழ்', enabled: true },
      { code: 'te', name: 'Telugu', native_name: 'తెలుగు', enabled: true },
      { code: 'ml', name: 'Malayalam', native_name: 'മലയാളം', enabled: true },
      { code: 'kn', name: 'Kannada', native_name: 'ಕನ್ನಡ', enabled: true },
      { code: 'gu', name: 'Gujarati', native_name: 'ગુજરાતી', enabled: true },
      { code: 'mr', name: 'Marathi', native_name: 'मराठी', enabled: true },
      { code: 'pa', name: 'Punjabi', native_name: 'ਪੰਜਾਬੀ', enabled: true },
      { code: 'ne', name: 'Nepali', native_name: 'नेपाली', enabled: true },
      { code: 'si', name: 'Sinhala', native_name: 'සිංහල', enabled: true },
      { code: 'my', name: 'Myanmar', native_name: 'မြန်မာ', enabled: true },
      { code: 'km', name: 'Khmer', native_name: 'ខ្មែរ', enabled: true },
      { code: 'lo', name: 'Lao', native_name: 'ລາວ', enabled: true },
      { code: 'ka', name: 'Georgian', native_name: 'ქართული', enabled: true },
      { code: 'am', name: 'Amharic', native_name: 'አማርኛ', enabled: true },
      { code: 'sw', name: 'Swahili', native_name: 'Kiswahili', enabled: true },
      { code: 'zu', name: 'Zulu', native_name: 'isiZulu', enabled: true },
      { code: 'af', name: 'Afrikaans', native_name: 'Afrikaans', enabled: true },
      { code: 'is', name: 'Icelandic', native_name: 'Íslenska', enabled: true },
      { code: 'mt', name: 'Maltese', native_name: 'Malti', enabled: true },
      { code: 'eu', name: 'Basque', native_name: 'Euskera', enabled: true },
      { code: 'ca', name: 'Catalan', native_name: 'Català', enabled: true },
      { code: 'gl', name: 'Galician', native_name: 'Galego', enabled: true },
      { code: 'cy', name: 'Welsh', native_name: 'Cymraeg', enabled: true },
      { code: 'ga', name: 'Irish', native_name: 'Gaeilge', enabled: true },
      { code: 'gd', name: 'Scottish Gaelic', native_name: 'Gàidhlig', enabled: true },
      { code: 'br', name: 'Breton', native_name: 'Brezhoneg', enabled: true },
      { code: 'co', name: 'Corsican', native_name: 'Corsu', enabled: true },
      { code: 'lb', name: 'Luxembourgish', native_name: 'Lëtzebuergesch', enabled: true }
    ]

    languages.each do |lang|
      execute <<-SQL
        INSERT INTO supported_languages (code, name, native_name, enabled, created_at, updated_at)
        VALUES ('#{lang[:code]}', '#{lang[:name].gsub("'", "''")}', '#{lang[:native_name].gsub("'", "''")}', #{lang[:enabled]}, NOW(), NOW())
        ON CONFLICT (code) DO NOTHING
      SQL
    end
  end

  def down
    # Revert language nomenclature changes
    execute <<-SQL
      UPDATE agent_templates
      SET language = REPLACE(language, '_', '-')
      WHERE language LIKE '%_%'
    SQL

    # Clear supported_languages table
    execute 'DELETE FROM supported_languages'
  end
end
