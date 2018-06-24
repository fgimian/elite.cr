require "json"
require "yaml"

struct YAML::Any
  # Checks that the underlying value is `Bool`, and returns its value.
  # Raises otherwise.
  def as_bool : Bool
    @raw.as(Bool)
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  # Returns `nil` otherwise.
  def as_bool? : Bool?
    @raw.as?(Bool)
  end

  class ConvertError < Error
  end

  def as_json
    convert_to_json(self)
  end

  private def convert_to_json(yaml) : JSON::Any
    data = case yaml.raw
    when Nil then yaml.as_nil
    when Bool then yaml.as_bool
    when Int64 then yaml.as_i64
    when Float64 then yaml.as_f
    when String then yaml.as_s
    when Array then yaml.as_a.map { |v| convert_to_json(v).as(JSON::Any) }
    when Hash
      hash = {} of String => JSON::Any
      yaml.as_h.each do |key, value|
        unless key.raw.is_a?(String)
          raise ConvertError.new("The hash key #{key} is not a string")
        end
        hash[key.as_s] = convert_to_json(value).as(JSON::Any)
      end
      hash
    else
      raise ConvertError.new("Unsupported type #{yaml.raw.class}")
    end

    JSON::Any.new(data)
  end
end
