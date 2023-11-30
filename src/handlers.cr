# handler.cr User's handlers
require "ecr"
require "uri"
require "log"
require "http/server/handler"

require "./session"
require "./body_parser"

module DojowHandlers
  extend self
  # typedef HttpRequest, HttpResponse
  alias HttpRequest = HTTP::Request
  alias HttpResponse = HTTP::Server::Response

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
  
  # HEAD Method
  def head(context, pattern : String | Regex, &)
    req = context.request
    res = context.response
    if req.method == "HEAD" && (req.path =~ pattern || req.path == pattern)
      yield(req, res, pattern)
    end
  end
  
  # Users' handlers
  def call(context)
    # if route is "/" then redirect index.html
    get context, "/" do |req, res, pattern|
      res.redirect("/index.html")
    end
    
    # Hello World!
    get context, "/hello" do  |req, res, pattern|
       res.content_type = "text/plain"
       res.puts "Hello World!"
    end
    
    # Echo
    get context, "/echo" do  |req, res, pattern|
      res.content_type = "text/plain"
      message = req.query_params.fetch("message", "None")
      res.puts "message = #{message}"
    end
        
    # Echo Form (GET)
    get context, "/echo_form" do |req, res, pattern|
      res.content_type = "text/html; charset=utf-8"
      message = ""
      res.print ECR.render "./templates/echo_form.ecr"
    end
    
    # Echo Form (POST)
    post context, "/echo_form" do |req, res, pattern|
      res.content_type = "text/html; charset=utf-8"
      message = req.form_params.fetch("message", "None")
      res.print ECR.render "./templates/echo_form.ecr"
    end
    
    # Session
    get context, "/session" do  |req, res, pattern|
      session = Session.create(req.cookies)
      res.content_type = "text/plain; charset=utf-8"
      if session.size > 0
        # If the cookies exists then echo them as Response.
        session.each do |k, v|
          res.puts "#{k}:#{v}"
        end
      else
        # If no cookies then send new cookies.
        Session.to_cookies({"MyCookie" => "ABCD"}).each do |c|
          res.cookies << c
        end
        res.puts "Sent new cookies."
      end
    end

    # Web service
    get context, "/webservice" do |req, res, pattern|
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
    get context, "/ws_test" do |req, res, pattern|
      sh = req.headers.serialize.gsub("\n", "\\n").gsub("\r", "")
      res.content_type = "application/json"
      res.puts %({"method":"#{req.method}", "host":"#{req.hostname}", "version":"#{req.version}", "headers":"#{sh}", "query":"#{req.query}", "path":"#{req.path}"})
    end

    # POST web service test
    post context, "/ws_test" do |req, res, pattern|
      sh = req.headers.serialize.gsub("\n", "\\n").gsub("\r", "")
      res.content_type = "application/json"
      res.puts %({"method":"#{req.method}", "host":"#{req.hostname}", "version":"#{req.version}", "headers":"#{sh}", "body":"#{req.body}", "path":"#{req.path}"})  
    end

    # HEAD web service test
    head context, "/ws_test" do |req, res, pattern|
      res.puts
    end

    # GET x-www-form-urlencoded
    get context, "/post_www_form" do |req, res, pattern|
      id = ""
      name = ""
      mchecked = "checked"
      fchecked = ""
      result = ""
      rendered = ECR.render "./templates/post_www_form.ecr"
      res.print rendered
    end
    # POST x-www-form-urlencoded
    post context, "/post_www_form" do |req, res, pattern|
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
    get context, "/post_multipart_form" do |req, res, pattern|
      number = "0"
      result = ""
      rendered = ECR.render "./templates/post_multipart_form.ecr"
      res.print rendered
    end
    post context, "/post_multipart_form" do |req, res, pattern|
      if req.body.nil?
        number = "0"
        filename = ""
        result = "Error: Reqquest.body is not defined."
        rendered = ECR.render "./templates/post_multipart_form.ecr"
        res.print rendered
      end
      io = req.body.as(IO)
      body = io.gets_to_end
      p! body
      boundary = "--" + BodyParser.getBoundary(req)
      dispositions = BodyParser.getDispositions(body, boundary)
      dispositions.each do |d|
        p! d
        if BodyParser.includesChunk?(d)
          name = BodyParser.getDispositionName(d)
          filename = BodyParser.getDispositionFileName(d)
          chunk = BodyParser.getDispositionChunk(d)
          p! name
          p! filename
          p! chunk
        else
          name = BodyParser.getDispositionName(d)
          value = BodyParser.getDispositionValue(d)
          p! name
          p! value
        end
      end
      rendered = ECR.render "./templates/post_multipart_form.ecr"
      res.print rendered
    end
    
    # POST FormData object
    get context, "/post_formdata" do |req, res, pattern|
      id = "0"
      name = ""
      vchecked = ""
      result = ""
      rendered = ECR.render "./templates/post_formdata.ecr"
      res.print rendered
    end
    post context, "/post_formdata" do |req, res, pattern|
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
    get context, "/post_blob" do |req, res, pattern|
      data = "00,01,02,03,04,0a,0b"
      result = ""
      rendered = ECR.render "./templates/post_blob.ecr"
      res.print rendered    
    end
    post context, "/post_blob" do |req, res, pattern|
      data = req.body.as(IO).getb_to_end
      result = "OK (#{data})"
      res.content_type = "text/plain";
      res.puts result
    end
    
    # TODO: Add your handlers.
    
  end # of call(context) method

end # of CommandHandler class

