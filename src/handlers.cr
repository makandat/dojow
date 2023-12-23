# handler.cr User's handlers
require "ecr"
require "uri"
require "log"
require "mime"
require "db"
require "sqlite3"
require "mysql"
require "http/cookie"
require "http/server/handler"

require "./dojow"
require "./session"
require "./body_parser"

module DojowHandlers
  extend self
  # typedef HttpRequest, HttpResponse
  alias HttpRequest = HTTP::Request
  alias HttpResponse = HTTP::Server::Response
  alias HttpStatus = HTTP::Status

  # GET Method
  def get(context, pattern : String | Regex, &)
    req = context.request
    res = context.response
    if req.method == "GET" && (req.path =~ pattern || req.path == pattern)
      yield(req, res, pattern)
    end
  end

  # POST Method
  def post(context, pattern : String | Regex, &)
    req = context.request
    res = context.response
    if req.method == "POST" && (req.path =~ pattern || req.path == pattern)
      yield(req, res, pattern)
    end
  end

  # Any methods
  def any(context, pattern : String | Regex, &)
    req = context.request
    res = context.response
    if req.path =~ pattern || req.path == pattern
      yield(req, res, pattern)
    end
  end
  
  # redirect to url
  def redirect(res : HttpResponse, url : String)
    html = <<-HEREDOC
<!doctype html>
<html>
<head>
 <title>redirect</title>
 <script>
   location.href = "#{url}";
 </script>
</head>
<body>
  <h3>redirect</h3>
</body>
</html>
HEREDOC
    res.content_type = "text/html; charset=utf-8"
    res.print html
  end
  
  # Show message
  def showMessage(res : HttpResponse, title : String, message : String, status : HttpStatus=HTTP::Status::OK)
    html = <<-HEREDOC
<!doctype html>
<html>
<head>
 <meta charset="utf-8">
 <title>#{title}</title>
</head>
<body>
  <h2 style="text-align:center;color:mediumvioletred; padding:12px;">#{title}</h2>
  <p style="text-align:center; font-size:large; margin-top:10px;">#{message}</p>
  <p style="text-align:center; font-size:large; margin-top:10px;"><a href="javascript:history.back();">BACK</a></p>
</body>
</html>
HEREDOC
    res.content_type = "text/html; charset=utf-8"
    res.status = status
    res.print html
  end

  # Get All Dispositions
  def getDispositions(req : HttpRequest) : Array(String)
    io = req.body.as(IO)
    body = io.gets_to_end
    boundary = "--" + BodyParser.getBoundary(req)
    dispositions = BodyParser.getDispositions(body, boundary)
  end

  # From posted body to hash
  def parseUrlEncodedBody(body : IO | Nil) : Hash(String, String)
    params = Hash(String, String).new
    if body.nil?
      return params
    end
    bodyString = body.as(IO).gets_to_end
    bodyItems = bodyString.split("&")
    bodyItems.each do |a|
      kv = a.split("=")
      k = kv[0]
      v = kv[1]
      params[k] = URI.decode(v)
    end
    return params
  end

  # Get bytes from body (of ArrayBuffer)
  def getBytes(body : IO | Nil) : Bytes
    if body.nil?
      return Slice(UInt8).empty
    end
    return body.as(IO).getb_to_end
  end

# ------------------------------- Users' handlers ------------------------
  # Users' handlers
  def call(context)
    # if route is "/" then redirect index.html
    get context, "/" do |req, res, pattern|
      res.redirect("/index.html")
    end

    # Hello World!
    get context, "/hello" do  |req, res|
       res.content_type = "text/plain"
       res.puts "Hello World!"
    end

    # Echo
    get context, "/echo" do  |req, res|
      res.content_type = "text/plain"
      message = req.query_params.fetch("message", "None")
      res.puts "message = #{message}"
    end

    # Echo Form (GET)
    get context, "/echo_form" do |req, res|
      res.content_type = "text/html; charset=utf-8"
      message = ""
      res.print ECR.render "./templates/echo_form.ecr"
    end

    # Echo Form (POST)
    post context, "/echo_form" do |req, res|
      res.content_type = "text/html; charset=utf-8"
      message = req.form_params.fetch("message", "None")
      res.print ECR.render "./templates/echo_form.ecr"
    end

    # Session
    get context, "/session" do  |req, res|
      session : Hash(String, String) = Session.create(req.cookies)
      res.content_type = "text/plain; charset=utf-8"
      if !session.empty?
        # If the cookies exists then echo them as Response.
        session.each do |k, v|
          res.puts "#{k}:#{v}"
        end
      else
        # If no cookies then send new cookies.
        c = Session.to_cookie({"MyCookie" => "ABCD"})
        res.cookies << c
        res.puts "Sent new cookies. MyCookie => ABCD"
      end
    end

    # Web service
    get context, "/webservice" do |req, res|
      res.content_type = "application/json"
      x = 1.2345
      if req.query_params.has_key?("value")
        x = req.query_params["value"].to_f64
      end
      hash = {"value" => x, "square" => x*x, "sqrt" => Math.sqrt(x.abs), "abs" => x.abs, "round" => x.round}
      res.print hash.to_json
    end

    # regex pattern
    get context, /\/regex\/\d+/ do |req, res, pattern|
      res.content_type = "text/plain; charset=utf-8"
      res.puts "request.path = #{req.path}"
      res.puts "request.pattern = #{pattern.to_s}"
    end

    # GET web service test
    get context, "/ws_test" do |req, res,|
      sh = req.headers.serialize.gsub("\n", "\\n").gsub("\r", "")
      res.content_type = "application/json"
      res.puts %({"method":"#{req.method}", "host":"#{req.hostname}", "version":"#{req.version}", "headers":"#{sh}", "query":"#{req.query}", "path":"#{req.path}"})
    end

    # POST web service test
    post context, "/ws_test" do |req, res|
      sh = req.headers.serialize.gsub("\n", "\\n").gsub("\r", "")
      res.content_type = "application/json"
      res.puts %({"method":"#{req.method}", "host":"#{req.hostname}", "version":"#{req.version}", "headers":"#{sh}", "body":"#{req.body}", "path":"#{req.path}"})
    end

    # HEAD web service test
    any context, "/ws_test" do |req, res|
      res.puts
    end

    # GET x-www-form-urlencoded
    get context, "/post_www_form" do |req, res|
      id = ""
      name = ""
      mchecked = "checked"
      fchecked = ""
      result = ""
      rendered = ECR.render "./templates/post_www_form.ecr"
      res.print rendered
    end
    # POST x-www-form-urlencoded
    post context, "/post_www_form" do |req, res|
      id = req.form_params["id"]
      name = req.form_params["name"]
      sex = req.form_params["sex"]
      if sex == "male"
        mchecked = "checked"
        fchecked = ""
      else
        mchecked = ""
        fchecked = "checked"
      end
      result = "OK (#{id}, #{name}, #{sex})"
      rendered = ECR.render "./templates/post_www_form.ecr"
      res.print rendered
    end

    # POST multipart_formdata
    get context, "/post_multipart_form" do |req, res|
      number = "0"
      result = ""
      rendered = ECR.render "./templates/post_multipart_form.ecr"
      res.print rendered
    end
    post context, "/post_multipart_form" do |req, res|
      number = "0"
      filename = ""
      chunk = ""
      result = ""
      if req.body.nil?
        number = "0"
        filename = ""
        result = "Error: Reqquest.body is not defined."
        rendered = ECR.render "./templates/post_multipart_form.ecr"
        res.print rendered
      end
      dispositions = getDispositions(req)
      # This part for testing.
      dispositions.each do |d|
        if BodyParser.includesChunk?(d)
          name = BodyParser.getDispositionName(d)
          filename = BodyParser.getDispositionFileName(d)
          chunk = BodyParser.getDispositionChunk(d)
        else
          name = BodyParser.getDispositionName(d)
          value = BodyParser.getDispositionValue(d)
        end
      end # end of testing
      number = BodyParser.getValue(dispositions, "number")
      filename = BodyParser.getFileName(dispositions, "file1")
      chunk = BodyParser.getChunk(dispositions, "file1").to_slice
      if filename.size > 0
        BodyParser.saveFile(filename, chunk)
      end
      cs = chunk.size
      result = "number=#{number}, filename=#{filename}, chunk.size=#{cs}"
      rendered = ECR.render "./templates/post_multipart_form.ecr"
      res.print rendered
    end

    # POST FormData object
    get context, "/post_formdata" do |req, res|
      id = "0"
      name = ""
      vchecked = ""
      result = ""
      rendered = ECR.render "./templates/post_formdata.ecr"
      res.print rendered
    end
    post context, "/post_formdata" do |req, res|
      id = req.form_params["id"]
      name = req.form_params["name"]
      if req.form_params["void"] == ""
        vchecked = ""
      else
        vchecked = "checked"
      end
      result = "OK (#{id}, #{name}, #{vchecked})"
      rendered = ECR.render "./templates/post_formdata.ecr"
      res.print rendered
    end

    # POST BLOB
    get context, "/post_blob" do |req, res|
      data = "00,01,02,03,04,0a,0b"
      result = ""
      rendered = ECR.render "./templates/post_blob.ecr"
      res.print rendered
    end
    post context, "/post_blob" do |req, res|
      data = req.body.as(IO).getb_to_end
      result = "OK (#{data})"
      res.content_type = "text/plain";
      res.puts result
    end

    # post_formdata2 (multipart)
    get context, "/post_formdata2" do |req, res|
      rendered = ECR.render "./templates/post_formdata2.ecr"
      res.print rendered
    end
    post context, "/post_formdata2" do |req, res|
      result = ""
      if req.body.nil?
        res.content_type = "text/plain";
        result = "The Request.body is empty."
      else
        dispositions = getDispositions(req)
        x = BodyParser.getValue(dispositions, "X")
        y = BodyParser.getValue(dispositions, "Y")
        filename = BodyParser.getFileName(dispositions, "file1")
        res.content_type = "application/json";
        result = %({"X":"#{x}", "Y":"#{y}", "file1":"#{filename}"})
      end
      res.puts result
    end

    # post_request (multipart)
    get context, "/post_request" do |req, res|
      rendered = ECR.render "./templates/post_request.ecr"
      res.print rendered
    end
    post context, "/post_request" do |req, res|
      result = ""
      if req.body.nil?
        res.content_type = MIME.from_extension(".txt")
        result = "The Request.body is empty."
      else
        dispositions = getDispositions(req)
        x = BodyParser.getValue(dispositions, "X")
        y = BodyParser.getValue(dispositions, "Y")
        z = BodyParser.getValue(dispositions, "Z")
        res.content_type = MIME.from_extension(".json")
        result = %({"X":"#{x}", "Y":"#{y}", "Z":"#{z}"})
      end
      res.puts result
    end

    # cookie2
    post context, "/cookie2" do |req, res|
      res.content_type = MIME.from_extension(".json")
      if req.body.nil?
        result = %({"Error":"The Request.body is empty."})
      else
        dispositions = getDispositions(req)
        name = BodyParser.getValue(dispositions, "name")
        value = BodyParser.getValue(dispositions, "value")
        expires = BodyParser.getValue(dispositions, "expires")
        max_age = BodyParser.getValue(dispositions, "max_age")
        res.cookies << HTTP::Cookie.new(name, value)
        if expires != ""
          res.cookies[name].expires = Time.parse_local(expires, "%Y-%m-%d %H:%M:%S")
        elsif max_age != ""
          res.cookies[name].max_age = Time::Span.new(nanoseconds:0)
        end
        data = String::Builder.new("{")
        # the existing cookie items
        req.cookies.each do |cookie|
          data << %("#{cookie.name}": )
          data << %("#{cookie.value})
          if !cookie.expires.nil?
            data << "; expires=#{cookie.expires}"
          elsif !cookie.max_age.nil?
            data << "; max-age=0"
          end
          data << "\", "
        end
        # the new cookie item
        data << %("#{name}": "#{value})
        if expires != ""
          data << %(; expires=#{expires})
        end
        if max_age != ""
          data << %(; max-age=#{max_age})
        end
        data << %("})
        res.print data.to_s
      end
    end

    # POST SQLite3 Links table
    #   create table Links (id integer primary key autoincrement,title text not null, url text not null, info text, new_page integer, regdate text);
    post context, "/sqlite3_links" do |req, res|
      connection = Dojow.get_setting("sqlite3")
      idq = req.form_params["id"]?
      if idq.nil?
        id = "null"
      else
        id = Int32.new(idq)
      end
      dispositions = getDispositions(req)
      title = BodyParser.getValue(dispositions, "title")
      url = BodyParser.getValue(dispositions, "url")
      info = BodyParser.getValue(dispositions, "info")
      new_page = BodyParser.getValue(dispositions, "new_page")
      target = 0
      if new_page == "on"
        target = 1
      end
      regdate = BodyParser.getValue(dispositions, "regdate")
      db = DB.open(connection)
      if id == "null"
        sql = "INSERT INTO Links VALUES(NULL, ?, ?, ?, ?, ?)"
        db.exec(sql, title, url, info, target, regdate)
      else
        sql = "UPDATE Links SET title=?, url=?, info=?, new_page=?, regdate=? WHERE id=?"
        db.exec(sql, title, url, info, target, regdate, id)
      end
      db.close
      response = %({"title":"#{title}", "url":"#{url}", "info":"#{info}", "new_page":#{target}, "regdate":"#{regdate}"})
      res.content_type = MIME.from_extension(".json")
      res.print response
    end

    # GET SQLite3 Links table
    #   create table Links (id integer primary key autoincrement,title text not null, url text not null, info text, new_page integer, regdate text);
    get context, "/sqlite3_links" do |req, res|
      connection = Dojow.get_setting("sqlite3")
      id = req.query_params["id"]
      db = DB.open(connection)
      rs = db.query_one("SELECT * FROM Links WHERE id=?", id, as: {Int32, String, String, String, Int32, String})
      db.close
      res.content_type = MIME.from_extension(".json")
      response = %({"id":#{id}, "title":"#{rs[1]}", "url":"#{rs[2]}", "info":"#{rs[3]}", "new_page":#{rs[4]}, "regdate":"#{rs[5]}"})
      res.print(response)
    end

    # MySQL Pictures table
    get context, /\/mysql_pictures\/\d+/ do |req, res|
      connection = Dojow.get_setting("mysql")
      id = req.path.split("/").pop
      db = DB.open(connection)
      begin
        rs = db.query_one("SELECT title, album, creator, path, media, mark, info, fav, count, bindata, date FROM Pictures WHERE id=?", id,
         as: {String, Int32, String, String, String, String, String, Int32, Int32, Int32, Time})
      rescue
        db.close
        res.content_type = "application/json"
        res.puts %({"error":"Result is empty."})
        return
      end
      sb = String::Builder.new("{")
      sb << %("id":#{id}, )
      sb << %("title":"#{rs[0]}", )  # title
      sb << %("album":#{rs[1]}, )  # album
      sb << %("creator":"#{rs[2]}", )  # creator
      sb << %("path":"#{rs[3]}", )  # path
      sb << %("media":"#{rs[4]}", )  # media
      sb << %("mark":"#{rs[5]}", )  # mark
      sb << %("info":"#{rs[6]}", )  # info
      sb << %("fav":#{rs[7]}, )  # fav
      sb << %("count":#{rs[8]}, )  # count
      sb << %("bindata":#{rs[9]}, )  # bindata
      sb << %("date":"#{rs[10].to_s()}")  # date
      sb << "}"
      db.close
      res.content_type = "application/json"
      res.print sb.to_s
    end

    # Redirect page
    get context, "/redirect" do |req, res|
      redirect(res, "redirect.html")
    end

    # Show message page
    get context, "/showMessage" do |req, res|
      showMessage(res, "テスト", "これはテストメッセージです。")
    end

    # TODO: Add your handlers.

  end # of call(context) method

end # of CommandHandler class

