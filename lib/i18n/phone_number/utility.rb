module I18n
  module PhoneNumber
    # Utility for international phone numbers. Functionality includes
    # formatting, parsing and validation.
    class Utility
      # This class implements a singleton.
      include Singleton

      # Flags to use when compiling regular expressions for phone numbers.
      REGEX_FLAGS = "i"

      # The minimum and maximum length of the national significant number.
      MIN_LENGTH_FOR_NSN = 3
      MAX_LENGTH_FOR_NSN = 15

      # The maximum length of the country code.
      MAX_LENGTH_COUNTRY_CODE = 3

      # Region-code for the unknown region.
      UNKNOWN_REGION = 'ZZ'

      NANPA_COUNTRY_CODE = 1

      # The PLUS_SIGN signifies the international prefix.
      PLUS_SIGN = '+'

      # These mappings map a character (key) to a specific digit that should
      # replace it for normalization purposes. Non-European digits that may be
      # used in phone numbers are mapped to a European equivalent.
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

      # Only upper-case variants of alpha characters are stored.
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

      # A list of all country codes where national significant numbers
      # (excluding any national prefix) exist that start with a leading zero.
      LEADING_ZERO_COUNTRIES = [
        39,   # Italy
        47,   # Norway
        225,  # Cote d'Ivoire
        227,  # Niger
        228,  # Togo
        241,  # Gabon
        242,  # Congo (Rep. of the)
        268,  # Swaziland
        378,  # San Marino
        379,  # Vatican City
        501   # Belize
      ]

      # Pattern that makes it easy to distinguish whether a country has
      # a unique international dialing prefix or not. If a country has
      # a unique international prefix (e.g. 011 in USA), it will be
      # represented as a string that contains a sequence of ASCII digits. If
      # there are multiple available international prefixes in a country, they
      # will be represented as a regex string that always contains
      # character(s) other than ASCII digits.  Note this regex also includes
      # tilde, which signals waiting for the tone.
      UNIQUE_INTERNATIONAL_PREFIX = Regexp.compile("[\\d]+(?:[~\u2053\u223C\uFF5E][\\d]+)?")

      # Regular expression of acceptable punctuation found in phone numbers.
      # This excludes punctuation found as a leading character only.  This
      # consists of dash characters, white space characters, full stops,
      # slashes, square brackets, parentheses and tildes. It also includes the
      # letter 'x' as that is found as a placeholder for carrier information
      # in some phone numbers.
      VALID_PUNCTUATION = "-x\u2010-\u2015\u2212\uFF0D-\uFF0F " +
        "\u00A0\u200B\u2060\u3000()\uFF08\uFF09\uFF3B\uFF3D.\\[\\]/~\u2053\u223C\uFF5E"

      # Digits accepted in phone numbers that we understand.
      VALID_DIGITS = DIGIT_MAPPINGS.keys.map { |i| i.gsub("[, \\[\\]]", "") }
      # We accept alpha characters in phone numbers, ASCII only, upper and
      # lower case.
      VALID_ALPHA = ALPHA_MAPPINGS.keys.map { |i| i.gsub("[, \\[\\]]", "") } +
        ALPHA_MAPPINGS.keys.map { |i| i.downcase.gsub("[, \\[\\]]", "") }

      PLUS_CHARS = "+\uFF0B"
      CAPTURING_DIGIT_PATTERN = Regexp.compile("([" + VALID_DIGITS.to_s + "])")

      # Regular expression of acceptable characters that may start a phone
      # number for the purposes of parsing. This allows us to strip away
      # meaningless prefixes to phone numbers that may be mistakenly given to
      # us. This consists of digits, the plus symbol and arabic-indic digits.
      # This does not contain alpha characters, although they may be used
      # later in the number. It also does not include other punctuation, as
      # this will be stripped later during parsing and is of no information
      # value when parsing a number.
      VALID_START_CHAR = "[" + PLUS_CHARS + VALID_DIGITS.to_s + "]"
      VALID_START_CHAR_PATTERN = Regexp.compile(VALID_START_CHAR)

      # Regular expression of characters typically used to start a second
      # phone number for the purposes of parsing. This allows us to strip off
      # parts of the number that are actually the start of another number,
      # such as for: (530) 583-6985 x302/x2303 -> the second extension here
      # makes this actually two phone numbers, (530) 583-6985 x302 and (530)
      # 583-6985 x2303. We remove the second extension so that the first
      # number is parsed correctly.
      SECOND_NUMBER_START = "[\\\\/] *x"
      SECOND_NUMBER_START_PATTERN = Regexp.compile(SECOND_NUMBER_START)

      # Regular expression of trailing characters that we want to remove. We
      # remove all characters that are not alpha or numerical characters. The
      # hash character is retained here, as it may signify the previous block
      # was an extension.
      UNWANTED_END_CHARS = "[[N&&L]&&[^#]]+$" # TODO: Fix replacement patterns.
      UNWANTED_END_CHAR_PATTERN = Regexp.compile(UNWANTED_END_CHARS)

      # We use this pattern to check if the phone number has at least three
      # letters in it - if so, then we treat it as a number where some
      # phone-number digits are represented by letters.
      VALID_ALPHA_PHONE_PATTERN = Regexp.compile("(?:.*?[A-Za-z]){3}.*")

      # Regular expression of viable phone numbers. This is location
      # independent. Checks we have at least three leading digits, and only
      # valid punctuation, alpha characters and digits in the phone number.
      # Does not include extension data.
      # The symbol 'x' is allowed here as valid punctuation since it is often
      # used as a placeholder for carrier codes, for example in Brazilian
      # phone numbers. We also allow multiple "+" characters at the start.
      # Corresponds to the following:
      # plus_sign?([punctuation]*[digits]){3,}([punctuation]|[digits]|[alpha])*
      # Note VALID_PUNCTUATION starts with a -, so must be the first in the range.
      VALID_PHONE_NUMBER = "[" + PLUS_CHARS + "]?(?:[" + VALID_PUNCTUATION +
        "]*[" + VALID_DIGITS.to_s + "]){3,}[" + VALID_ALPHA.to_s +
        VALID_PUNCTUATION + VALID_DIGITS.to_s + "]*"

      # Default extension prefix to use when formatting. This will be put in
      # front of any extension component of the number, after the main
      # national number is formatted. For example, if you wish the default
      # extension formatting to be " extn: 3456", then you should specify
      # " extn: " here as the default extension prefix. This can be overridden
      # by country-specific preferences.
      DEFAULT_EXTN_PREFIX = " ext. "

      # Regexp of all possible ways to write extensions, for use when parsing.
      # This will be run as a case-insensitive regexp match. Wide character
      # versions are also provided after each ascii version. There are two
      # regular expressions here: the more generic one starts with optional
      # white space and ends with an optional full stop (.), followed by zero
      # or more spaces/tabs and then the numbers themselves. The other one
      # covers the special case of American numbers where the extension is
      # written with a hash at the end, such as "- 503#".
      # Note that the only capturing groups should be around the digits that
      # you want to capture as part of the extension, or else parsing will
      # fail!
      # Canonical-equivalence doesn't seem to be an option with Android java,
      # so we allow two options for representing the accented o - the
      # character itself, and one in the unicode decomposed form with the
      # combining acute accent.
      KNOWN_EXTN_PATTERNS = "[ \u00A0\\t,]*(?:ext(?:ensio)?n?|" +
        "\uFF45\uFF58\uFF54\uFF4E?|[,x\uFF58#\uFF03~\uFF5E]|int|anexo|\uFF49\uFF4E\uFF54)" +
        "[:\\.\uFF0E]?[ \u00A0\\t,-]*([" + VALID_DIGITS.to_s + "]{1,7})#?|[- ]+([" + VALID_DIGITS.to_s +
        "]{1,5})#"

      # Regexp of all known extension prefixes used by different countries
      # followed by 1 or more valid digits, for use when parsing.
      EXTN_PATTERN = Regexp.compile("(?:" + KNOWN_EXTN_PATTERNS + ")$", REGEX_FLAGS)


      # We append optionally the extension pattern to the end here, as a valid
      # phone number may have an extension prefix appended, followed by 1 or
      # more digits.
      VALID_PHONE_NUMBER_PATTERN = Regexp.compile(VALID_PHONE_NUMBER +
        "(?:" + KNOWN_EXTN_PATTERNS + ")?", REGEX_FLAGS)

      NON_DIGITS_PATTERN = Regexp.compile("(\\D+)")
      FIRST_GROUP_PATTERN = Regexp.compile("(\\$1)")
      NP_PATTERN = Regexp.compile("\\$NP")
      FG_PATTERN = Regexp.compile("\\$FG")
      CC_PATTERN = Regexp.compile("\\$CC")

      # INTERNATIONAL and NATIONAL formats are consistent with the definition
      # in ITU-T Recommendation E. 123. For example, Swiss number will be
      # written as "+41 44 668 1800" in INTERNATIONAL format, and as "044 668
      # 1800" in NATIONAL format. E164 format is as per INTERNATIONAL format
      # but with no formatting applied, e.g.  +41446681800.
      #
      # Note: If you are considering storing the number in a neutral format,
      # you are highly advised to use the phonenumber.proto.
      PHONE_NUMBER_FORMATS = [ "E164", "INTERNATIONAL", "NATIONAL" ]

      # Type of phone numbers.
      PHONE_NUMBER_TYPES = [
        "FIXED_LINE",
        "MOBILE",
        # In some countries (e.g. the USA), it is impossible to distinguish
        # between fixed-line and mobile numbers by looking at the phone number
        # itself.
        "FIXED_LINE_OR_MOBILE",
        # Freephone lines
        "TOLL_FREE",
        "PREMIUM_RATE",
        # The cost of this call is shared between the caller and the
        # recipient, and is hence typically less than PREMIUM_RATE calls. See
        # http://en.wikipedia.org/wiki/Shared_Cost_Service for more
        # information.
        "SHARED_COST",
        # Voice over IP numbers. This includes TSoIP (Telephony Service over
        # IP).
        "VOIP",
        # A personal number is associated with a particular person, and may be
        # routed to either a MOBILE or FIXED_LINE number. Some more
        # information can be found here:
        # http://en.wikipedia.org/wiki/Personal_Numbers
        "PERSONAL_NUMBER",
        "PAGER",
        # Used for "Universal Access Numbers" or "Company Numbers". They may
        # be further routed to specific offices, but allow one number to be
        # used for a company.
        "UAN",
        # A phone number is of type UNKNOWN when it does not fit any of the
        # known patterns for a specific country.
        "UNKNOWN"
      ]

      # Types of phone number matches. See detailed description beside the
      # isNumberMatch() method.
      MATCH_TYPE = [
        "NOT_A_NUMBER",
        "NO_MATCH",
        "SHORT_NSN_MATCH",
        "NSN_MATCH",
        "EXACT_MATCH"
      ]

      # Possible outcomes when testing if a PhoneNumber is possible.
      VALIDATION_RESULT = [
        "IS_POSSIBLE",
        "INVALID_COUNTRY_CODE",
        "TOO_SHORT",
        "TOO_LONG"
      ]

      def initialize(phone_number, country_code)
        @phone_number = phone_number
        @country_code = country_code
      end

      def extract_possible_number(number)
        if VALID_START_CHAR_PATTERN.match(number)
          # Remove trailing non-alpha non-numerical characters.
          if UNWANTED_END_CHAR_PATTERN.match(number)
            # number = number.substring(0, trailingCharsMatcher.start())
          end
          # Check for extra numbers at the end.
          if SECOND_NUMBER_START_PATTERN.match(number)
            # number = number.substring(0, secondNumber.start())
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
end
