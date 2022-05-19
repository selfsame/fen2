## TODO

### basics

- [ ] lua bindings
  - [x] print to console (this was just lua 'print')
  - [x] draw pixel
  - [ ] draw primitives
  - [ ] draw font

### systems

- [ ] 'application' struct
  - [/] inject bindings
  - [/] load fennel and loaders
  - [ ] folder 'app' structure
    - [ ] run lua from 'app' cwd
    - [ ] `app.fnl`, can require other files normally
    - [ ] watch files, live reload
  - [ ] error handling (at least just print the error and recover)

- [ ] OS
  - [ ] 'app' processes, focused app
  - [ ] `input` and `update` routing

- [ ] multiple applications
- [ ] input and input routing

- [ ] img format
- [ ] img section blitting
- [ ] pattern fill

- [ ] fen2 user storage
  - [ ] windows, linux, localStorage
- [ ] sandbox filesystem access
