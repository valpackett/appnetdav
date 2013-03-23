require 'em-http-request'

module EventMachine::HttpDecoders
  class GZip
    def decompress(compressed)
      @buf ||= LazyStringIO.new
      @buf << compressed
      # Zlib::GzipReader loads input in 2048 byte chunks
      if @buf.size > 2048
        @gzip ||= Zlib::GzipReader.new @buf
        @gzip.readpartial(2048)
      else
        ""
      end
    end
  end
end
