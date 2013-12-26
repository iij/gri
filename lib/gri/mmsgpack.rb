# coding: us-ascii

class Fixnum
  def to_msgpack
    if (self >= -32 and self <= 127)
      [self].pack('c')
    elsif self < 4294967296
      "\xd2"+[self].pack('N')
    else
      "\xcf"+[(self>>32), (self&0xffffffff)].pack('N2')
    end
  end
end

class Bignum
  def to_msgpack
    "\xcf"+[(self>>32), (self&0xffffffff)].pack('N2')
  end
end

class Float
  def to_msgpack
    if self < 4294967296
      "\xce"+[(self/65536).to_i, self%65536].pack('n2')
    else
      "\xcf"+[(self/281474976710656).to_i,
        (self/4294967296%65536).to_i,
        (self%4294967296/65536).to_i, self%65536].pack('n4')
    end
  end
end

class Nil
  def to_msgpack
    "\xc0"
  end
end

class String
  def to_msgpack
    "\xdb"+[self.size].pack('N')+self
  end
end

class Array
  def to_msgpack
    "\xdc" + [self.size].pack('n') +
      self.map {|e| e.to_msgpack}.join('')
  end
end

class Hash
  def to_msgpack
    "\xde" + [self.size].pack('n') +
      self.map {|k, v| k.to_msgpack + v.to_msgpack}.join('')
  end
end
