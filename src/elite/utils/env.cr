# Provides additional functions to convert the environment to and from a hash
module ENV
  def self.to_h
    env = {} of String => String
    ENV.each { |key, value| env[key] = value }
    env
  end

  def self.from(hash : Hash)
    hash.each { |key, value| ENV[key] = value }
    keys_to_remove = Set.new(ENV.keys) - hash.keys
    keys_to_remove.each { |key| ENV.delete(key) }
  end
end
