## TODO

### basics

- [ ] lua bindings
  - [x] print to console (this was just lua 'print')
  - [ ] draw pixel
  - [ ] draw primitives
  - [x] draw font
    - [ ] newlines
  - [ ] clear screen
  - [x] blit texture

### systems

- [ ] 'application' struct
  - [x] inject bindings
  - [x] load fennel and loaders
  - [ ] folder 'app' structure
    - [ ] run lua from 'app' cwd
    - [ ] `app.fnl`, can require other files normally
    - [ ] watch files, live reload (https://docs.rs/notify/latest/notify/)
  - [ ] error handling (at least just print the error and recover)

- [ ] OS
  - [ ] 'app' processes, focused app
  - [ ] `input` and `update` routing

- [ ] multiple applications
- [ ] input and input routing

- [ ] img format
- [ ] img section blitting
- [ ] pattern fill
- [ ] post processing that enforces 2 bit color

- [ ] fen2 user storage
  - [ ] windows, linux, localStorage
- [ ] sandbox filesystem access



# Log

## 5-19-2022

Figured out https://docs.rs/notify/5.0.0-pre.15/notify/ has a `try_recv` to not block, seems to be reliable (i.e. not missing any events). Next I want to match on `NoticeWrite` event and reload the specific lua file in question.

Reading https://technomancy.us/189 to figure out how to reload fennel files, it mentions `package.path` which might help set each app's root path.

Believe i have a reload fn (had to slightly modify the emacs quoted one from that link) but I'm having trouble understanding the lua and fennel module system, mainly i just want to call a fn i defined in the previous require

## 5-20-2022

The `reload` works so next I want to move it into some sort of utility module. After that I'd like to have file changes reload the specific module that file created (I'm guessing there might be some metadata in the package table).  I imagine it will be tricky testing paths against each other.

I have a `system.fnl` module for general fennel code.  Wanted to move the test drawing snippet into `app.fnl` but realized I would need to pump an `update`, tried setting that up by calling `app.update` if it exists but after reload `app` is nil.. oh duh reload probably needs to return something.

This is working great, some TODO for tomorrow:

-[x] delta in update
-[ ] clear screen
-[ ] input polling

## 5-21-2022

Good morning, I am reading about https://docs.rs/notify/latest/notify/enum.DebouncedEvent.html, think `NoticeWrite` really indicates some writing events are starting so maybe i should use `Write` with like a 100ms debounce window. Actually now that I play with it the double reload when i first start changing a file is not from two notify events, must be some fennel thing with `reload`?

"clear screen" brings up a consideration, am i going to be drawing to one texture or providing bindings to create textures that get drawn in the shader.

Tinkering with macroquad's text rendering, I want pixel perfect bitmap fonts, it uses truetype.  There's no exposed filtering options for the text renderer, but it looks like if I guess the right font size with a pixel ttf font i can get no dithering (using size 16 with http://www.pentacom.jp/pentacom/bitfontmaker2/gallery/?id=381 for example). I can just hard code the font sizes and force the user to use integer text locations.

I still need to figure out how to make the fonts global, the ttf loader is async which i can't put in lazy static i guess.

Ended up using a `Mutex<HashMap<String, Font>>` which like.. doesn't feel great but it's working.

## 5-22-2022

Good morning, I would like to sort out sprite rendering today.  Had some issues loading textures because it was async and lua bindings are sync, ended up with a mutex hashset of image paths to load that gets drained in the main loop. (goofy but it's working). 

Next i probably need to look into 
- [ ] image alpha
- [ ] clipping (maybe render textures? all I really need is squares)

Closing thoughts for the night, `(print (fennel.view package.loaded))` shows all loaded code keyed by the module path, apparently they can have `/` or `.` separators

```
   :files.testapp.util {:frog #<function: 000001A42BF9DDE0>}
   :files/testapp/app {:update #<function: 000001A42C080940>}
   :files/testapp/util {:frog #<function: 000001A42C1CA680>}
```

I'll just need to identify which of these path fragment keys match the file path that changed and `reload` all matching keys

## 5-23-2022

Let's try setting the working directory for the lua processes and resolving the specific file that changed.

changing the working directory to the "app" but first problem is my fennel and system files are elsewhere, worried that lua needs to be spun up with the right cwd for it's searchers. Guess i could load those two files from rust/hlua.. 

OK thinking my easiest route is to add BASE_PATH to package.path, then i should be able to load `fennel.lua` and `system.fnl` with no fuss. ... This worked (had to add it to fennel.path as well) My app is running with it's own root path, and seems like `load_img` and `require` is also working from this new root.

Small fix giving the test app an absolute root path, eventually these will come from scanning the user file system.

Oh a caveat i was in the app cwd when the first `_handle_unloaded_textures` was called, so image loading worked but the keys were app local.  I probably want to either fully qualify the image paths or have a texture store for each app.