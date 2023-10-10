# handler.cr User's handlers
require "ecr"
require "log"
require "./cs_handlers"
require "./session"

module DojowHandlers
  extend self

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
       res.content_type = "text/plain; charset=utf-8"
       res.puts "Hello World!"
    end
    
    # Echo
    get context, "/echo" do  |req, res, pattern|
      res.content_type = "text/plain; charset=utf-8"
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

