# Dojow server
require "log"
require "json"
require "http/server"
require "./cs_handlers"
require "./handlers"

# Dojow module
module Dojow
  extend self
  # Constants
  VERSION = "0.6.0"
  CONFIG = "./dojow.json"
  LOGNAME = "http.server"

  # Aliases
  alias HttpRequest = HTTP::Request
  alias HttpResponse = HTTP::Server::Response

  # Read the settings file
  def read_settings(file_path : String) : Hash(String, String)
    json_text = File.read(file_path)
    Hash(String, String).from_json(json_text)  
  end
  
  # CompressHandler
  def compress_handler : HTTP::CompressHandler
    HTTP::CompressHandler.new
  end

  # ErrorHandler
  def error_handler(name : String, logfile : String) : HTTP::ErrorHandler
    backend = ::Log::IOBackend.new(File.new(logfile, "a"))
    ::Log.setup do |c|
      c.bind(name, :info, backend)
    end
    log = ::Log.for(name)
    HTTP::ErrorHandler.new(true, log)
  end

  # LogHandler
  def log_handler(name : String, logfile : String) : HTTP::LogHandler
    backend = ::Log::IOBackend.new(File.new(logfile, "a"))
    ::Log.setup do |c|
      c.bind(name, :debug, backend)
    end
    log = ::Log.for(name)
    HTTP::LogHandler.new(log)
  end

  # StaticFileHandler
  def static_handler(static : String) : HTTP::StaticFileHandler
    HTTP::StaticFileHandler.new(static, true, false)
  end

  # CGIHandler
  def cgi_handler(path : String)
    CustomHandlers::CGIHanlder.new(path)
  end

  # CommandHandler
  def command_handler
    CustomHandlers::CommandHandler.new
  end

  # DefaultHandler
  def default_handler(public_html)
    CustomHandlers::DefaultHandler.new(public_html)
  end
  
  # Create Dojow HTTP Server
  def create(verbose : Bool = false) : HTTP::Server
    # Read settings
    settings = read_settings(CONFIG)
    # Create HTTP Handlers
    errorh = error_handler(LOGNAME, settings["error"])
    statich = static_handler(settings["static"])
    logh = log_handler(LOGNAME, settings["log"])
    cgih = cgi_handler(settings["cgi-bin"])
    commandh = command_handler
    defaulth = default_handler(settings["static"])
    # Create HTTP Server
    server = HTTP::Server.new([ errorh, statich, logh, cgih, commandh, defaulth ]) do |context|
      puts %(#{context.request.method}, #{context.request.hostname}, #{context.request.path}) if verbose
      DojowHandlers.call(context)
    end
  end
  
  # Listen to the requests from the clients.
  def listen(server : HTTP::Server, host : String = "127.0.0.1", port : Int32 = 2023)
    server.bind_tcp(host, port)
    unless host == "localhost" || host == "127.0.0.1"
      server.bind_tcp("localhost", port)
    end
    server.listen
  end
end
