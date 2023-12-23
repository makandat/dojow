# Session variables
require "http/cookie"
require "uri"
require "json"

module Session
  extend self
  SESSION_NAME = "dojow_session"
  
  # Create the session hash variable
  def create(cookies : HTTP::Cookies) : Hash(String, String)
    session = Hash(String, String).new
    if cookies.has_key?(SESSION_NAME)
      c = cookies[SESSION_NAME]
      dv =  URI.decode(c.value)
      session = Hash(String, String).from_json(dv)
    end
    return session
  end
 
  # Convert session hash to cookie
  def to_cookie(session : Hash(String, String)) : HTTP::Cookie
    v = URI.encode_path(session.to_json)
    c = HTTP::Cookie.new(SESSION_NAME, v)
    return c
  end
end
