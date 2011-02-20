require "i18n/phone_number/utility"

module I18n
  module PhoneNumber
    METADATA = YAML.load(File.read("#{File.dirname(__FILE__)}/data.yml"))
  end
end
