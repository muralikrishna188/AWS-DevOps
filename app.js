function add(a, b) {
  return a + b;
}

function greet(name) {
  return `Hello, ${name}!`;
}

module.exports = { add, greet };

if (require.main === module) {
  const http = require('http');
  http
    .createServer((req, res) => {
      res.end(greet('CodeBuild Automation'));
    })
    .listen(3000, () => console.log('Listening on port 3000'));
}
