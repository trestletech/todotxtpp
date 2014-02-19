## todo.txt-node

### todo.txt-node is a Node.js port of todo.txt-cli.

todo.txt-node is a near drop-in replacement for todo.txt-cli (todo.sh):

- line-by-line port from todo.sh bash script to todo.coffee coffeescript
- passes 345 tests from todo.txt-cli test suite

Major differences between todo.txt-node and todo.txt-cli:

- todo.txt-node depends only on Node.js; Cygwin/Linux not required.
- todo.txt-node can be used as a library and called from other JavaScript applications.
- todo.txt-node does not support add-ons or Bash command line completion.


**Installation:**  *([Node.js](http://nodejs.org/) required)*

`npm -g install todo.txt-node`

**How to Use from the Command Line:** *just like todo.sh*

`todo help` *In case of conflict with another `todo` command on your computer,
you can also use `ntodo`*


More information:

- [todo.txt-cli (todo.sh) documentation](https://github.com/ginatrapani/todo.txt-cli/wiki/User-Documentation) - this documentation also applies to todo.txt-node, except for add-on's and bash command line completion.
- Official [todo.txt site](http://todotxt.com/)
- The [todo.txt file format](https://github.com/ginatrapani/todo.txt-cli/wiki/The-Todo.txt-Format)


**How to Use from Your Own JavaScript Project:**

Documentation coming soon... meanwhile, here are two examples:

- from Node: [todo.txt-node](https://github.com/Leftium/todo.txt-node/blob/master/src/wrapper.coffee)
- from web (RequireJS AMD): [todo.html](https://github.com/Leftium/todo.html/blob/master/src/coffee/main.coffee)

