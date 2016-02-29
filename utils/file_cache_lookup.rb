require 'utils/cache_lookup'

# A subclass of Cache_Lookup that caches to an external file in addition to an internal hash. The internal hash takes precedence, but the file will be sought if the internal hash lacks the item.
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby

class File_Cache_Lookup < Cache_Lookup
  # Like Cache_Lookup, except the second argument is a file_lambda that takes the items to be cached and returns a path to the file. The file should be named distinctly in using hash_lambda's result as part of the name
  def initialize(cache_name, file_lambda, hash_lambda=lambda {|item| item.hash})
    super(cache_name, hash_lambda)
    @file_lambda = file_lambda
  end

  # Add the item to the internal hash and marshals it to the file
  def add(item, value)
    #Rescape::Config.log.info("#{@cache_name}: Adding item keyed by: #{@hash_lambda.call(item)}")
    @lookup_hash[@hash_lambda.call(item)] = value
    path = @file_lambda.call(item)
    File.open(path, 'w+') do |wf|
      save_to_file(value, wf)
    end
  end

  def member?(item)
    found = @lookup_hash.member?(@hash_lambda.call(item))
    found = found || File.exists?(@file_lambda.call(item))
    #Rescape::Config.log.info("#{@cache_name}: Cache #{found ? 'hit' : 'miss'} for item #{item}")
    found
  end

  def find_or_nil(item)
    value = @lookup_hash[@hash_lambda.call(item)]
    #Rescape::Config.log.info("#{@cache_name}: File Cache in memory hit for item #{item.inspect}") if value
    value || find_in_file_or_nil(item)
  end

  def find_in_file_or_nil(item)
    file_name = @file_lambda.call(item)
    #Rescape::Config.log.info("#{@cache_name}: File Cache lookup for file_name #{file_name}")
    if (File.exists?(file_name))
    #  Rescape::Config.log.info("#{@cache_name}: File Cache hit for item #{item.inspect}")
      File.open(file_name) do |f|
        load_from_file(f)
      end
    else
      $item = item
    #  Rescape::Config.log.info("#{@cache_name}: File Cache miss for item #{item.inspect}")
      nil
    end
  end

  def load_from_file(f)
    Marshal.load(f)
  end

  def save_to_file(item, f)
    Marshal.dump(item, f)
  end

  def clear!
    # Try to delete all the cached files
    @lookup_hash.values.each {|item|
      path = @file_lambda.call(item)
      File.unlink(path)
    }
    @lookup_hash.clear()
  end
end