# handler.cr User's handlers
require "ecr"
require "uri"
require "log"
require "http/server/handler"

require "./session"

module DojowHandlers
  extend self
  # typedef HttpRequest, HttpResponse
  alias HttpRequest = HTTP::Request
  alias HttpResponse = HTTP::Server::Response

  # CGI Handler
  class CGIHanlder
    include HTTP::Handler
    
    # constructor
    def initialize(cgipath : String, verbose=false)
      @cgipath = cgipath
      @verbose =verbose
    end
    
    # overidden method
    def call(context)
      Log.info {@cgipath} if @verbose
      req = context.request
      res = context.response
      if req.path.to_s.starts_with?("/cgi-bin/")
        r, w = IO.pipe
        param = ""
        unless req.body.nil?
          param = req.body.as(IO).gets_to_end
        end
        w << param
        w.close
        query_string = ""
        if req.query_params.size > 0
          req.query_params.each do |k, v|
            query_string += "#{k}=#{v}&"
          end
          query_string = query_string[0 ... query_string.size-1]
        end
        r2, w2 = IO.pipe
        filepath = req.path.to_s.sub("/cgi-bin", @cgipath)
        Process.run(filepath, nil, shell:true, env:{"QUERY_STRING" => query_string}, input:r, output:w2)
        w2.close
        lines = r2.gets_to_end.lines
        headers = get_headers(lines)
        content = lines[headers.size + 1 ..]
        res.content_type = headers[0].split(": ")[1]
        if headers.size > 1
          headers[1 ..].each do |header|
            if header.starts_with?("Cookie: ")
              name = header.split(": ")[0]
              value = header.split(": ")[1]
              res.cookies << HTTP::Cookie.new(name, value)
            end
          end
        end
        content.each do |line|
          res.puts line
        end
      end
      call_next(context)
    end
    
    # get the response headers
    def get_headers(lines) : Array(String)
      headers = [] of String
      lines.each do |line|
        if line == ""
          break
        end
        headers.push(line)
      end
      return headers
    end
  end # of class
  
  # Command handler
  class CommandHandler
      include HTTP::Handler
    
    # constructor
    def initialize(verbose : Bool = false)
      @verbose = verbose
    end

    # handler
    def call(context)
      req = context.request
      res = context.response
      if req.path.to_s.starts_with?("/command")
        parts = [] of String
        dir = nil
        if req.method == "GET"
          parts = req.query_params["cmd"].split(" ")
          Log.info {parts[1]} if @verbose
          if req.query_params.has_key?("dir")
            dir = req.query_params["dir"]
          end
        elsif req.method == "POST"
          parts = req.form_params["cmd"].split(" ")
          if req.form_params.has_key?("dir")
            dir = req.form_params["dir"]
          end
        else
          res.respond_with_status(:bad_request, "BAD REQUEST")
          return
        end
        cmd = parts[0]
        args = parts[1 ..]
        r, w = IO.pipe
        Process.run(cmd, args, chdir:dir, shell:true, output:w)
        w.close
        res.content_type = "text/plain; charset=utf-8"
        res.print r.gets_to_end
      end
      call_next(context)
    end
  end


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

    # TODO: Add your handlers.
    
  end
end

