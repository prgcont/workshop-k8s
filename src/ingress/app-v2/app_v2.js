const http = require('http');
const os = require('os');

console.log("Gordon server starting...");

var handler = function(request, response) {
  console.log("Received request from " + request.connection.remoteAddress);
  response.writeHead(200);
  response.end("Hey, I'm the next version of gordon; my name is " + os.hostname() + "\n");
};

var www = http.createServer(handler);
www.listen(8080);
