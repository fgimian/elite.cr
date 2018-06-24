require "json"

# TODO: Consider a better name?
module Elite::Utils::JSON2
  # Deeply compares the source hash against the destination ensuring that all items contained
  # in the source are also in and equal to the destination.
  def self.deep_equal?(source : JSON::Any, destination : JSON::Any) : Bool
    if destination.raw.is_a?(Hash) && source.raw.is_a?(Hash)
      source.as_h.each do |key, value|
        return false unless destination.as_h.has_key?(key) && deep_equal?(value, destination[key])
      end
      true
    else
      source == destination
    end
  end

  # Deep merges the source hash into the destination and returns the resulting object.
  def self.deep_merge(source : JSON::Any, destination : JSON::Any) : JSON::Any
    if destination.raw.is_a?(Hash) && source.raw.is_a?(Hash)
      updated_destination = destination.as_h.dup

      source.as_h.each do |key, value|
        if value.raw.is_a?(Hash)
          node = destination[key]? || JSON::Any.new({} of String => JSON::Any)
          updated_destination[key] = deep_merge(value, node)
        else
          updated_destination[key] = value
        end
      end

      JSON::Any.new(updated_destination)
    else
      source
    end
  end
end
