# Addons to the String class
#
# Author::    Andy Likuski (andy@likuski.org)
# License::   Distributes under the same terms as Ruby


class String

  # Converts the string of hex digits to binary digits
  # From http://stackoverflow.com/questions/862140/hex-to-binary-in-ruby/6719730#6719730
  def hex2bin()
    s = self
    raise "Not a valid hex string" unless(s =~ /^[\da-fA-F]+$/)
    s = '0' + s if((s.length & 1) != 0)
    s.scan(/../).map{ |b| b.to_i(16) }.pack('C*')
  end

  # Converts the string of binary digits to hex digits
  # From http://stackoverflow.com/questions/862140/hex-to-binary-in-ruby/6719730#6719730
  def bin2hex()
    self.unpack('C*').map{ |b| "%02X" % b }.join('')
  end
end