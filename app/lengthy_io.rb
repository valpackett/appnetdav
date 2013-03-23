class LengthyIO < Struct.new(:io, :length)
  def read(*args)
    io.read(*args)
  end

  def method_missing(meth, *args)
    io.call(meth, *args)
  end
end
