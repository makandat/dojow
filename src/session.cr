# Session variables
module Session
  extend self

  # Create the session variable
  def create(cookies : HTTP::Cookies) : Hash(String, String)
    session = Hash(String, String).new
    from_cookies(session, cookies)
  end

  # Convert from cookies
  def from_cookies(session : Hash(String, String), cookies : HTTP::Cookies) : Hash(String, String)
    cookies.each do |c|
      session[c.name] = c.value
    end
    return session
  end
  
  # Convert to cookie
  def to_cookies(session : Hash(String, String)) : HTTP::Cookies
    cookies = HTTP::Cookies.new
    session.each do |k, v|
      c = HTTP::Cookie.new(k, v)
      cookies << c
    end
    return cookies
  end
end
