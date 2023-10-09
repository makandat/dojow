# Dojow server
require "./dojow.cr"

# Parsing command options
verbose = false
help = false
if ARGV.size > 0
  verbose = true if ARGV[0] == "-v"
  help = true if ARGV[0] == "-h"
end

# Create HTTP/Server object and listen
if help
   puts <<-EOS
# options
  -v verbose
  -h show help
# config file (dojow.json")
  The config file is required which named "dojow.json".
  The keys and values must be string.
  (example)
  {
  "static":"./html",
  "cgi-bin":"./cgi-bin",
  "error":"./log/error.log",
  "log":"./log/server.log",
  "host":"192.168.1.4",
  "port":"2023"
 }
EOS
else
  begin
    host = "localhost"
    port = 2023
    settings = Dojow.read_settings(Dojow::CONFIG)
    if settings.has_key?("host")
      host = settings["host"]
    end
    if settings.has_key?("port")
      port = settings["port"].to_i32
    end
    server = Dojow.create(verbose)
    puts "Dojow server version #{Dojow::VERSION} is listening #{host}:#{port} .."
    Dojow.listen(server, host, port)
  rescue e
    puts e.message
  end
end
