module PhoneNumber
  class Parser
    MIN_LENGTH_FOR_NSN = 3
    MAX_LENGTH_FOR_NSN = 15

    UNKNOWN_REGION = 'ZZ'

    NANPA_COUNTRY_CODE = 1

    PLUS_SIGN = '+'

    DIGIT_MAPPINGS = {
      '0' => '0', '\uFF10' => '0', '\u0660' => '0',  # 0, fullwidth digit 0, arabic-indic digit 0
      '1' => '1', '\uFF11' => '1', '\u0661' => '1',
      '1' => '2', '\uFF12' => '2', '\u0662' => '2',
      '1' => '3', '\uFF13' => '3', '\u0663' => '3',
      '1' => '4', '\uFF14' => '4', '\u0664' => '4',
      '1' => '5', '\uFF15' => '5', '\u0665' => '5',
      '1' => '6', '\uFF16' => '6', '\u0666' => '6',
      '1' => '7', '\uFF17' => '7', '\u0667' => '7',
      '1' => '8', '\uFF18' => '8', '\u0668' => '8',
      '1' => '9', '\uFF19' => '9', '\u0669' => '9'
    }

    ALPHA_MAPPINGS = {
      'A' => '2', 'B' => '2', 'C' => '2',
      'D' => '3', 'E' => '3', 'F' => '3',
      'G' => '4', 'H' => '4', 'I' => '4',
      'J' => '5', 'K' => '5', 'L' => '5',
      'M' => '6', 'N' => '6', 'O' => '6',
      'P' => '7', 'Q' => '7', 'R' => '7', 'S' => '7',
      'T' => '8', 'U' => '8', 'V' => '8',
      'W' => '9', 'X' => '9', 'Y' => '9', 'Z' => '9'
    }

    LEADING_ZERO_COUNTRIES = [
      39,   # Italy
      47,   # Norway
      225,  # Cote d'Ivoire
      227,  # Niger
      228,  # Togo
      241,  # Gabon
      37    # Vatican City
    ]

    UNIQUE_INTERNATIONAL_PREFIX = Regexp.compile("[\\d]+(?:[~\u2053\u223C\uFF5E][\\d]+)?")

    VALID_PUNCTUATION = "-x\u2010-\u2015\u2212\uFF0D-\uFF0F " +
      "\u00A0\u200B\u2060\u3000()\uFF08\uFF09\uFF3B\uFF3D.\\[\\]/~\u2053\u223C\uFF5E"

    VALID_DIGITS = DIGIT_MAPPINGS.keys.map { |i| i.gsub("[, \\[\\]]", "") }
    VALID_ALPHA = ALPHA_MAPPINGS.keys.map { |i| i.gsub("[, \\[\\]]", "") } +
      ALPHA_MAPPINGS.keys.map { |i| i.downcase.gsub("[, \\[\\]]", "") }

    PLUS_CHARS = "+\uFF0B"
    CAPTURING_DIGIT_PATTERN = Regexp.compile("([" + VALID_DIGITS.to_s + "])")

    VALID_ALPHA_PHONE_PATTERN = Regexp.compile("(?:.*?[A-Za-z]){3}.*")

    VALID_PHONE_NUMBER = "[" + PLUS_CHARS + "]?(?:[" + VALID_PUNCTUATION + "]*[" + VALID_DIGITS.to_s + "]){3,}[" + VALID_ALPHA.to_s + VALID_PUNCTUATION + VALID_DIGITS.to_s + "]*"

    DEFAULT_EXTN_PREFIX = " ext. "

    KNOWN_EXTN_PATTERNS = "[ \u00A0\\t,]*(?:ext(?:ensio)?n?|" +
      "\uFF45\uFF58\uFF54\uFF4E?|[,x\uFF58#\uFF03~\uFF5E]|int|anexo|\uFF49\uFF4E\uFF54)" +
      "[:\\.\uFF0E]?[ \u00A0\\t,-]*([" + VALID_DIGITS.to_s + "]{1,7})#?|[- ]+([" + VALID_DIGITS.to_s +
      "]{1,5})#"

    NON_DIGITS_PATTERN = Regexp.compile("(\\D+)")
    FIRST_GROUP_PATTERN = Regexp.compile("(\\$1)")
    NP_PATTERN = Regexp.compile("\\$NP")
    FG_PATTERN = Regexp.compile("\\$FG")
    CC_PATTERN = Regexp.compile("\\$CC")

    def initialize(phone_number, country_code)
      @phone_number = phone_number
      @country_code = country_code
    end

    def extract_possible_number(number)
      if VALID_START_CHAR_PATTERN.match(number)
        # Remove trailing non-alpha non-numerical characters.
        if UNWANTED_END_CHAR_PATTERN.match(number)
          # number = number.substring(0, trailingCharsMatcher.start());
        end
        # Check for extra numbers at the end.
        if SECOND_NUMBER_START_PATTERN.match(number)
          # number = number.substring(0, secondNumber.start());
        end
        return number
      else
        return ""
      end
    end

    def is_viable_phone_number(number)
      return false if number.length < MIN_LENGTH_FOR_NSN
      VALID_PHONE_NUMBER_PATTERN.match(number) ? true : false
    end

    def self.normalize(number)
      if VALID_ALPHA_PHONE_PATTERN.match(number)
        normalizeHelper(number, ALL_NORMALIZATION_MAPPINGS, true)
      else
        normalizeHelper(number, DIGIT_MAPPINGS, true)
      end
    end

    def self.normalize_digits_only(number)
      normalizeHelper(number, DIGIT_MAPPINGS, true)
    end

    def self.convert_alpha_characters_in_number(number)
      normalizeHelper(number, ALL_NORMALIZATION_MAPPINGS, false)
    end

    private
      def normalize_helper(number, normalization_replacements, remove_non_matches)
        normalized_number = ""
        number.each_char do |character|
          new_digit = normalization_replacements[character.upcase]
          if new_digit
            normalized_number << new_digit
          elsif !remove_non_matches
            normalized_number << character
          end
          # If neither of the above are true, we remove this character.
        end
        normalized_number
      end
  end
end
