# MultipartFormData module
require "http/server"
require "uri"

module BodyParser
  extend self

  # get bounrary string
  def getBoundary(req : HTTP::Request) : String
    boundary = ""
    if req.headers.has_key?("content-type")
      content_type = req.headers["content-type"]
      parts = content_type.split("; ")
      if parts.size == 2
        if parts[0] == "multipart/form-data" && parts[1].starts_with?("boundary")
          b = parts[1].split("=")
          if b.size == 2
            boundary = b[1]
          end
        end
      end
    end
    return boundary
  end

  # get dispositions
  def getDispositions(body : String, boundary : String) : Array(String)
    disps = body.split(boundary)
    well = Array(String).new
    disps.each do |s|
      if !s.index("Content-Disposition: form-data;").nil?
        well.push(s)
      end
    end
    return well
  end

  # If the disposition include a chunk, then return true.
  def includesChunk?(disposition : String) : Bool
    return !disposition.index("Content-Type: ").nil?
  end

  # save string to file
  def saveFile(filename : String, chunk : String) : String
    savePath = "./upload/#{filename}"
    f = File.new(savePath, mode="wb")
    f.print(chunk)
    f.close
    return savePath
  end

  # save bytes to file
  def saveFile(filename : String, chunk : Bytes)
    f = File.new("./upload/" + filename, mode="wb")
    f.write(chunk)
    f.close
  end

  # get the disposition name
  def getDispositionName(disposition : String) : String
    p = disposition.index(%(Content-Disposition: form-data; name="))
    if p.nil?
      return ""
    else
      p1 = p.as(Int32)
      p1 += %(Content-Disposition: form-data; name=").size
    end
    q = disposition.index("\"", p1)
    if q.nil?
      return ""
    else
      return disposition[p1 .. q.as(Int32) - 1]
    end
  end

  # get the disposition value (INTERNAL USE)
  def getDispositionValue(disposition : String) : String
    p = disposition.index("Content-Type: ")
    if !p.nil?
      return ""
    else
      lines = disposition.split("\r\n")
      n = lines.size - 2
      if n < 0
        return ""
      end
    end
    return lines[n]
  end

  # get filename of the disposition if exists (INTERNAL USE)
  def getDispositionFileName(disposition : String) : String
    p = disposition.index("Content-Disposition: form-data; name=\"")
    if p.nil?
      return ""
    else
      p1 = p.as(Int32)
      p1 += "Content-Disposition: form-data;".size
      p2 = disposition.index("filename=\"", p1).as(Int32)
      p2 += "filename=\"".size
      q = disposition.index("\"", p2)
      if q.nil?
        return ""
      else
        return disposition[p2 .. q.as(Int32) - 1]
      end
    end
  end

  # get the chunk if content-type is octed stream (INTERNAL USE)
  def getDispositionChunk(disposition : String) : String
    p = disposition.index("filename=")
    if p.nil?
      return ""
    else
      p1 = p.as(Int32)
      p2 = disposition.index("\r\n\r\n", p1).as(Int32) + 4
      chunk = disposition[p2 .. disposition.size - 3]
      return chunk
    end
  end

  def getName(disposition : String) : String
    return getDispositionName(disposition)
  end

  # get the value of the name
  def getValue(dispositions : Array(String), name : String) : String
    name1 = ""
    dispositions.each do |d|
      name1 = getDispositionName(d)
      if name == name1
        s = URI.decode(getDispositionValue(d))
        return s
      end
    end
    return ""
  end

  # get the chunk of the name
  def getChunk(dispositions : Array(String), name : String) : String
    name1 = ""
    dispositions.each do |d|
      if includesChunk?(d)
        name1 = getDispositionName(d)
        if name == name1
          chunk = getDispositionChunk(d)
          if chunk.starts_with?("\r\n")
            chunk = chunk[2 ..]
          end
          return URI.decode(chunk)
        end
      end
    end
    return ""
  end

  # get filename of the name
  def getFileName(dispositions : Array(String), name : String) : String
    name1 = ""
    dispositions.each do |d|
      if includesChunk?(d)
        name1 = getDispositionName(d)
        if name == name1
          filename = getDispositionFileName(d)
          return URI.decode(filename)
        end
      end
    end
    return ""
  end

end # module


BODY = %{-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="file1"; filename="data.txt"
Content-Type: application/octet-stream

AAAAAAAAAAAAAAAAAAAAAAAAAAAA
BBBBBBBBBBBBBBBBBBBBBBBBBBBB
CCCCCCCCCCCCCCCCC
-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="title"

TITLE
-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="path"

/post_request_json
-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="methods"

GET,POST
-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="query"

id
-----------------------------26767473973547735812633686047
Content-Disposition: form-data; name="info"

GetRow medaka by id
-----------------------------26767473973547735812633686047--
}

