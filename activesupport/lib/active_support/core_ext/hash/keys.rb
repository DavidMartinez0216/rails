class Hash
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    dup.stringify_keys!
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+.
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  # ==== Examples
  #   { :name => "Rob", :years => "28" }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key: years"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys("name", "age") # => raises "ArgumentError: Unknown key: name"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys(:name, :age) # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    valid_keys.flatten!
    each_key do |k|
      raise(ArgumentError, "Unknown key: #{k}") unless valid_keys.include?(k)
    end
  end

  # Validate that all *required_keys are included in hash, otherwise it will raise an ArgumentError.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  # *required_keys*: list of keys that must be present in hash for it to be valid
  #
  # ==== Examples
  #   {:name => 'Phil'}.assert_required_keys(:name) # => will not raise error
  #   {:name => nil}.assert_required_keys(:name) # => will not raise error
  #
  #   {:age => 28 }.assert_required_keys(:name) # => raises ArgumentError
  #   {'name' => 'Phil'}.assert_required_keys(:name) # => raises ArgumentError
  def assert_required_keys(*required_keys)
    keys_not_passed = [required_keys].flatten - keys
    raise(ArgumentError, "The following keys are required but were not set: #{keys_not_passed.map(&:inspect).join(", ")}") unless keys_not_passed.empty?
  end
end
