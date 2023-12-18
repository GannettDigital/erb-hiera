require "hiera"

module ErbHiera
  class Hiera
    def initialize(scope, verbose, local_hiera)
      @local_hiera = local_hiera
      @scope = scope
      @verbose = verbose
      @cache = {}
      ::Hiera.logger = "noop"
    end

    def hiera(key)
      if @cache.has_key?("priority_#{key}") then
        value = @cache["priority_#{key}"]
      else
        value = @local_hiera.lookup(key, nil, @scope, nil, :priority)
        @cache["priority_#{key}"] = value
      end

      unless value
        raise KeyError.new("Hiera lookup failed",nil,key)
      end

      puts "# #{key}: #{value}" if @verbose
      value
    end

    def hiera_array(key)
      if @cache.has_key?("array_#{key}") then
        value = @cache["array_#{key}"]
      else
        value = @local_hiera.lookup(key, nil, @scope, nil, :array)
        @cache["array_#{key}"] = value
      end

      unless value
        puts "\nerror: cannot find value for key: #{key}"
        exit 1
      end

      puts "# #{key}: #{value}" if @verbose
      value
    end

    def hiera_hash(key)
      if @cache.has_key?("hash_#{key}") then
        value = @cache["hash_#{key}"]
      else
        value = @local_hiera.lookup(key, nil, @scope, nil, :hash)
        @cache["hash_#{key}"] = value
      end

      unless value
        puts "\nerror: cannot find value for key: #{key}"
        exit 1
      end

      puts "# #{key}: #{value}" if @verbose
      value
    end

    def get_binding
      binding
    end
  end
end
