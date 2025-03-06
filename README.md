## TODO

### basics

- [ ] lua bindings
  - [x] print to console (this was just lua 'print')
  - [ ] draw pixel
  - [/] draw primitives
  - [x] draw font
    - [ ] newlines
  - [ ] clear screen
  - [x] blit texture

### systems

- [x] 'application' struct
  - [x] inject bindings
  - [x] load fennel and loaders
  - [x] folder 'app' structure
    - [x] run lua from 'app' cwd
    - [x] `app.fnl`, can require other files normally
    - [x] watch files, live reload (https://docs.rs/notify/latest/notify/)
  - [x] error handling (at least just print the error and recover)

## OS
- [x] 'app' processes, focused app
- [x] `input` and `update` routing
- [/] "operating system" is just a fennel app that can manage window draw_targets, focus

- [x] img section blitting
- [ ] pattern fill
- [ ] post processing that enforces 2 bit color

- [ ] fen2 user storage
  - [ ] windows, linux, localStorage
- [ ] sandbox filesystem access


## API

```fnl
(clear_screen true)
(load_img "img/foo.png")
(draw_img x y "img/foo.png")
(draw_sprite x y sx sy w h "img/foo.png")
(draw_text "HELLO" x y true)

(draw_rect x y w h false)
(draw_rect_lines x y w h thickness true)

(load_sound "bar.wav")
(play_sound "bar.wav" false 0.2)

(mouse_pos)
(mouse_down 0)
(mouse_pressed 0)

(key_down "tab")
(key_pressed "q")
(key_released "x")

(list_files "dir/")
(quit)
```
