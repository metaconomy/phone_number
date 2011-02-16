require "phone_number/parser"

module PhoneNumber
  METADATA = YAML.load(File.read("#{File.dirname(__FILE__)}/data.yml"))
end
