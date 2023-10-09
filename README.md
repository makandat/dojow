# Dojow HTTP server

Dojow HTTP Server is an HTTP server written in the Crystal language.
This HTTP server is based on the HTTP/Server that is included in Crystal's standard library with the following additional features:

* Static file access (HTTP/StaticFileHandler)
* Create a web application by adding your own handler
* Creating web applications using user-created CGI
* Logging  (HTTP/LogHandler)
* Error log (HTTP/ErrorHanlder)
* Execute Linux command



## Installation

Just copy the folder "dojow" to the appropriate location.


## Usage

Execute "run" script in the folder.

## Development

Run "build" script in the dojow folder. If the build is successful, ./bin/dojow will be created.

### Add your own handler

Add your own handler in the "call(context)" method.

(Example)
```
    # Hello World!
    get context, "/hello" do  |req, res, pattern|
       res.content_type = "text/plain"
       res.puts "Hello World!"
    end
```


## Contributing

1. Fork it (<https://github.com/makandat/dojow/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [makandat](https://github.com/makandat) - creator and maintainer
