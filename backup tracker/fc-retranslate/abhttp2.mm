/*
  A HTTP protocol implementation (currently client only). This allows to
  send a HTTP request and process its response, accessing contents, cookies
  and other header fields. Chunked reads are handled properly.
  <p>Sample usage:
  <pre>
// get the airbit logo into a file
s:abhttp.Socket=abhttp.Socket("www.airbit.ch", 80);
s.request(abhttp.GET, "/media/14/logo.jpg");
if s.handleResponse()=200 then
  print "Date:",s.fields["Date"];
  f=io.create("airbit.jpg");
  b=s.readContent(1024); // just any buffer size
  while b#null do
    io.write(f, b);
    b=s.readContent(1024)
  end;
  io.close(f)
end;
s.close()
</pre>
  The module also supports simple URL parsing and connection caching via
  {@link abhttp.parseUrl} and {@link abhttp.connect}, {@link abhttp.request}.
  The example above can thus be simplified to:
  <pre>
url="http://www.airbit.ch/media/14/logo.jpg";
s:abhttp.Socket=abhttp.request(url, abhttp.GET);
if s.handleResponse()=200 then
  ...
</pre></p>
*/

// $Id: abhttp.mm 37 2009-06-29 10:27:55Z l.knecht $

use net, io, array, encoding, time

/*
  The GET method string.
*/
const GET="GET"
/*
  The HEAD method string.
*/
const HEAD="HEAD"
/*
  The POST method string.
*/
const POST="POST"
const POSTfile="POSTfile"

/*
  Encode an array of parameters.
  @param params the parameter array (with keys). May be null.
  @return the encoded and concatenated parameters.
*/
function encodeparams(params)
  res="";
  if params#null then
    for name in keys(params) do
      if len(res)#0 then res=res+"&" end;
      // x-f: fix, 20101205
      // res=res+encoding.touri(name)+"="+encoding.touri(params[name])
      res = res + encoding.touri(str(name)) + "=" + encoding.touri(str(params[name]));
    end
  end;
  return res
end

// x-f
function encodeparams_array(params)
  res="";
  if params#null then
    for item in params do
      if len(res) # 0 then res = res + "&"; end;
      name = keys(item)[0];
      value = item[name];
      res = res + encoding.touri(str(name)) + "=" + encoding.touri(str(value));
    end;
      
  end;
  return res
end

/*
  Parse a URL into host, port and path. Recognized prefixes are 
  <code>"http:"</code> and <code>"https:"</code>.
  @param url the URL.
  @return <code>["host":host,"port":port,"path":path]</code>.
*/
function parseUrl(url)
  p=split(url, "/");
  // check protocol
  if p[0]="http:" or p[0]="" then
    port=80
  elsif p[0]="https:" then
    port=443
  else
    throw "Unsupported protocol in "+url
  end;
  // URL must contain at least two slashes
  if len(p)<3 or len(p[1])#0 then
    throw "Invalid URL "+url
  end;
  // check for port in host part
  p2=split(p[2],":");
  if len(p2)=2 then
    try
      port=num(p2[1])
    catch e by
      throw "Invalid port in URL "+url
    end;
    if p[0]="https:" and port#443 then
      throw "Invalid SSL port in URL "+url
    end
  end;
  if len(p)=3 then
    path="/"
  else
    path="";
    for i=3 to len(p)-1 do
      path=path+"/"+p[i]
    end
  end;
  return ["host":p2[0],"port":port,"path":path]
end

/*
  A HTTP client socket.
*/
class Socket
  /*
    The name of the host to connect to (if not null, will also be used as HTTP
    host name).
  */
  host
  /*
    The port to connect to (may be null).
  */
  port
  /*
    The underlying socket stream.
  */
  stream
  /*
    The keep-alive mode: null for no keep alive, a timeout (in seconds) for
    keep alive.
  */
  keepAlive
  /*
    The request fields, as an array indexed by the field name.
  */
  fields
  /*
    The cookies, as an array indexed by the cookie name.
  */
  cookies
  /*
    A stream (file) to write all incoming data to.
  */
  dumpin
  /*
    A stream (file) to write all outgoing data to.
  */
  dumpout
  /* @internal */
  at
  /* @internal */
  chunklen
  /* @internal */
  expires

  /*
    Connect this socket to a stream.
    @param stream the stream to connect to. If null, a stream is created from
    host and port.
  */
  function connect(stream=null)
    if stream=null then
      secure=null;
      if port=443 then secure=net.ssl end;
      stream=net.conn(host, port, secure)
    end;
    io.flush(stream, false);
    this.stream=stream
  end

  /*
    Create a new HTTP socket, either from a TCP/IP socket or a host/port pair.
    @param hostOrStream a host name, or a socket stream.
    @param port a port number, or null if creating from a socket.
    If <code>port=443</code>, the connection will be made with ssl.
    @param keepAlive the value for the keepAlive field. If null, a new
    connection will be created for each request. If keepAlive=null and
    port=null, only one request can be sent without re-init.
  */
  function init(hostOrStream, port=null, keepAlive=300)
    this.port=port; this.keepAlive=keepAlive;
    if port=null then
      stream=hostOrStream; host=null
    else
      host=hostOrStream; connect()
    end;
    if cookies=null then cookies=[] end
  end

  /*
    Write a string to the socket.
    @param s the string.
  */
  function write(s)
    if dumpout#null then io.write(dumpout, s) end;
    io.write(stream, s)
  end

  /*
    Write a string and a CRLF pair to the socket.
    @param s the string.
  */
  function writeln(s)
    if dumpout#null then io.writeln(dumpout, s) end;
    io.writeln(stream, s)
  end

  /*
    Flush the socket, sending all output.
  */
  function flush()
    io.flush(stream)
  end

  /*
    Close the socket.
  */
  function close()
    if stream#null then
      io.close(stream); stream=null
    end
  end

  /*
    Send a request.
    @param method the request method ({@link GET}, {@link HEAD}, {@link POST}).
    @param path the request path.
    @param params the request parameters.
    @param fields the extra header fields, as an array indexed by name.
  */
  function request(method, path, params=null, fields=null, encodearray=false)
    if stream=null then connect() end;

    if (method = ..POSTfile) then
      // file upload request
      write("POST");
    else
      write(method);
    end;
    write(" "); write(path);

    if method=..GET or method=..HEAD then
      if encodearray then
        s = encodeparams_array(params);
      else
        s=encodeparams_array(params);
      end;
      if len(s)#0 then
        if index(path,"?")<0 then write("?") end;
        write(s)
      end
    end;
    writeln(" HTTP/1.1");
    if host#null then
      writeln("Host: " + host)
    end;
    if keepAlive#null then
      writeln("Keep-Alive: " + keepAlive);
      writeln("Connection: keep-alive")
    else
      writeln("Connection: close")
    end;
    if cookies#null then
      for name in keys(cookies) do
        write("Cookie: "); write(name); write("="); writeln(cookies[name])
      end
    end;
    if fields#null then
      for name in keys(fields) do
        write(name); write(": "); writeln(fields[name])
      end
    end;
    
    if method = ..POST then
      if encodearray then
        s = encodeparams_array(params);
      else
        s=encodeparams(params);
      end;

      writeln("Content-Type: application/x-www-form-urlencoded");
      writeln("Content-Length: " + len(s));
      writeln(""); write(s);
    end;
    
    if method = ..POSTfile then
      boundary = "xf" + time.str(time.get(), 'hhmmss');
      writeln("Content-Type: multipart/form-data, boundary=" + boundary);
      
      data = "";
      for index in keys(params) do
        value = params[index];
        if (index # "file") then
          data = data + "--" + boundary + "\r\n";
          data = data + "Content-Disposition: form-data; name=\"" + index + "\"\r\n";
          data = data + "\r\n" + value + "\r\n";
          data = data + "--" + boundary + "\r\n";
        else
          data = data + "--" + boundary + "\r\n";
          data = data + "Content-Disposition: form-data; name=\"file\"; filename=\"filename\"\r\n";
          data = data + "Content-Type: application/octet-stream\r\n";
          data = data + "\r\n" + value + "\r\n";
          data = data + "--" + boundary + "--\r\n";
        end;
      end;
            
      writeln("Content-Length: " + len(data));
      writeln("");
      write(data);
    end;

    if method # ..POST and method # ..POSTfile then
      writeln("");
    end;
    
    flush();
  end

  /*
    Read a number of bytes from the socket.
    @param len the number of bytes to read.
    @return the string read.
  */
  function read(len)
    s=io.read(stream, len);
    if dumpin#null and s#null then io.write(dumpin, s) end;
    return s
  end

  /*
    Read a line up to a maximum length from the socket.
    @param maxlen the maximum number of bytes to read.
    @return the string read (without line end mark).
  */
  function readln(maxlen=1024)
    s=io.readln(stream, maxlen);
    if dumpin#null and s#null then io.writeln(dumpin, s) end;
    if s#null then io.read(stream, 1) end;
    return s
  end

  /*
    Get the number of bytes which can be read without blocking.
    @return the available bytes.
  */
  function avail()
    return io.avail(stream)
  end

  /* @internal */
  function readHeaders()
    s=readln();
    while s#null and len(s)#0 do
      i=index(s, ":");
      if i>0 then
        name=substr(s,0,i);
        do
          i++
        until i>=len(s) or code(s,i)>32;
        s=substr(s,i);
        if lower(name)="set-cookie" then
          i=index(s,"=");
          if i>0 then
            name=substr(s,0,i); s=substr(s,i+1);
            i=index(s,";");
            if i>=0 then s=substr(s,0,i) end;
            cookies[name]=s
          end
        else
          fields[name]=s;
          if lower(name)="transfer-encoding" and lower(s)="chunked" then
            chunklen=-1
          end
        end
      end;
      s=readln()
    end
  end

  /*
    Handle a response, i.e. parse a response header. This sets up various
    internal fields, and allows to subsequently read the content via
    readContent().
    @return the response code, e.g. 200 for OK. Numeric if it is a number.
  */
  function handleResponse()
    code=null;
    fields=array.new(0, true);
    at=0; chunklen=null;
    s=readln();
    if s=null or len(s)=0 then
      return null
    end;
    i=index(s, " ");
    if i>=0 then
      i++; j=index(s, " ", i);
      if j<0 then code=substr(s, i)
      else code=substr(s, i, j-i) end;
      try
        code=num(code)
      catch e by end // ignore
    end;
    readHeaders();
    return code
  end

  /*
    Get a field from the response header.
    @param name the field name (e.g. "Content-Type"), not case sensitive.
    @return the field contents, or null if there is no such field.
  */
  function field(name)
    return fields[name]
  end

  /*
    Get a numeric field from the response header.
    @param name the field name (e.g. "Content-Length"), not case sensitive.
    @return the field value, or -1 if there is no such field or it does not
    contain a valid decimal number.
  */
  function numfield(name)
    try
      return num(field(name))
    catch e by
      return -1
    end
  end

  /*
    Read up to a given number of bytes from the content.
    @param len the number of bytes to read.
    @return the content chunk, or null if there is no more content to read.
  */
  function readContent(len)
    if chunklen#null then
      if at>=chunklen and chunklen#0 then
        // read next chunk
        if chunklen>0 then readln() end;
        chunklen=hexnum(readln()); at=0;
        // if at end, read more header fields
        if chunklen=0 then
          readHeaders()
        end
      end;
      avail=chunklen-at
    else
      avail=numfield("Content-Length")-at
    end;
    if avail<=0 then
      if keepAlive=null then
        close()
      end;
      return null
    end;
    if len>avail then len=avail end;
    s=read(len);
    at+=len(s);
    return s
  end

  /*
    Discard all remaining bytes of content.
  */
  function discardContent()
    while readContent(1024)#null do
    end
  end
end

/*
  The cache of existing sockets, indexed by <code>"host:port"</code>.
*/
sockets=[]

/*
  Close and and remove any expired socket.
*/
function closeExpired()
  now=time.utc(); i=0;
  while i<len(..sockets) do
    s:Socket=..sockets[i];
    if s.expires<now then
      s.close(); array.remove(..sockets, i)
    else
      i++
    end
  end
end

/*
  Get a connected socket by its URL, going through the connection cache.
  @param url the URL (only host and port are used).
  @param ttl the time to live for the socket (in seconds).
  @return the socket.
*/
function connect(url, ttl=240): Socket
  closeExpired();
  hpp=parseUrl(url);
  key=hpp["host"]+":"+hpp["port"];
  s:Socket=..sockets[key];
  if s=null or s.stream=null then
    s=Socket(hpp["host"], hpp["port"], ttl+60);
    ..sockets[key]=s
  end;
  // update expiry time
  s.expires=time.utc()+ttl;
  return s
end

/*
  Send a request to an URL, and return its socket, going through the connection
  cache.
  @param url the URL defining the host and path.
  @param method the request method ({@link GET}, {@link HEAD}, {@link POST}).
  @param params the request parameters.
  @param fields the extra header fields, as an array indexed by name.
  @return the socket to get the response from, and to call
  {@link Socket.handleResponse} on.
  See also {@link Socket.request}.
*/
function request(url, method, params=null, fields=null, encodearray=false): Socket
  s:Socket=connect(url);
  hpp=parseUrl(url);
  s.request(method, hpp["path"], params, fields, encodearray);
  return s
end
