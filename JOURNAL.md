
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

## 5-24-2022

Yeah lets have a per app texture store, then the memory should be freed as well when an app closes. ... ..... ... OK that didn't work out. I tried changing the lua bindings to closures so they could call app methods for the texture stuff (because app now had the texture store) but to Rust that means moving app into the closure.

Apparently that global Mutex wasn't the worst pattern for this.  I can probably do something like:
* give each app a uuid
* have a hashmap of hashmaps for each app's uuid

That'll let me avoid collisions and clear texture memory when I destruct the apps.

## 5-25-2022

Fennel game jam started today, going to try and do something platformer-like while working on this this week. Maybe good goals for tonight will be mouse input and cursors.

mouse input done, there's no built in cursor stuff. `show_mouse` is very hit or miss, at least as a runtime thing you toggle.

I got the filewatcher reload to target the exact file, which is great! should be able to reload images in the future as well when they change.

## 5-26-2022

Going to do jam stuff tonight: working on a sprite sheet and a map editor.

## 6-7-2022

Thinking over a few things:
* Maybe i want to stick with hlua for the speed, and i can just ship with a lua .so for linux.
* I can just use render textures for my windows. It would be nice to expose a scissor clip though.

There's https://github.com/not-fl3/macroquad/blob/4d383d6b69d6c7a3a540d61283d108b6c86980b6/src/quad_gl.rs#L791 but I'm not sure how to access the QuadGL instance, `macroquad::get_context()` is private.

(answer from macroquad discord: `unsafe { get_internal_gl() }.quad_gl.scissor(...)`)

## 6-09-2022

Still thinking about how I want to handle windows.  An issue with creating render textures for each window is they might be weird to resize. An advantage is that apps don't have to draw themselves every frame, and you can have nice shuffled windows.  You could also do windows with clipping but it's less feasable.  Clipping would be an important feature in general in `app` space though (think scrolling textboxes).

The top level `system` process would also need a handle (literal) on windows and their driving texture/clipping bounds. I am unsure on the relationship of the `system` to app processes, like, in terms of execution ordering.

### system only calls

* `launch_process(path) -> process_id` Instantiates a lua process with a handle id

* `close_process(process_id)`

* `assign_render_texture(render_texture_id, process_id)` ????

* `destroy_render_texture(render_texture_id)`

* `update_process(process_id)` queues the process for execution ( or maybe switches to the process's context to update it then continues? )

### app calls

* `quit()` closes the app process

* `new_window(w, h, title) -> render_texture_id`

* `close_window(render_texture_id)`

* `set_window(render_texture_id)` activates the render texture and camera

* `window_size(render_texture_id) -> int, int` gets the `system` determined size of the window

* `window_is_open(render_texture_id) -> bool` health check in case the system decided to close this window

* `set_clip(x, y, w, h)` sets a scissor clip

* `clear_clip()`



# 6-10-2022

Still chewing the problem of how to have apps request windows managed by a userland `system` without any kind of direct lua to lua communication between the two. (not against that just don't want to puzzle it out)... Perhaps apps can request 0-N render_texture handles and focus them for drawing.  The `system` can access info on an app's windows (i.e. render_textures) so that it can draw them how and where it pleases. `system` can also set a size value on app windows and close them.

^ this works for my use cases (vintage mac style window management and maybe a hybrid tiling window manager). It's nicely decoupled too, the worst scenario i can think of is an app requesting mutiple windows on a system that doesn't handle that (or that wants to force a size the app doesn't draw for)

# 10-14-2022

Picking this back up! Giving a fennel conf talk in about a month on it.  Hoping to have the system / process abstaction locked down by that point.  When I last worked on this I was stuck on how to make App structs globally accessible, as their lifetime prevented them from being in a Mutex Hashmap.  Tonight I am trying to figure out just how I can do App::new(&Path) with a non static String for the path. I think since it takes a borrowed reference there's no way this could work. I can't just take an owned PathBuf because it's size isn't known at compile time.  Maybe i can take something that's on the heap?

# 10-16-2022

Yeah instead of borrowing a Path and having to use a lifetime for the App struct that contained it I just had to use PathBuf so the struct owns it.  Everything I had wanted to do should be straight forward now!

Next steps: 
[ ] Have system launch another process and pass update to it every frame
[ ] sandboxed file listing
[ ] start working through system fns described above

# 10-17-2022

System App gets some extra bindings. Successfully loaded a second process BUT now I'll have to ensure the working directory of the loaded process is set.  System can be expected to refer to files relative to files/system so that's fine. I think what's going on is the launched process sets the working directory correctly but all the macroquad resource loading is done in the main loop which still has the system working directory set.

# 10-18-2022

Exhausted tonight but my thought is that i need to prepend resource paths with the working directory.  I can create a closure around the lua create_function calls to curry an argument, but the `root` path string doesn't live long enough for that. I may need to init the lua stuff after the App struct has been created.

Notes about sandboxing Lua: http://lua-users.org/wiki/SandBoxes

# 10-19-2022

Having a real hard time getting information into the function closure (my app's path so i can prepend it to load calls). Going to read a bit about closures and moving.

I ended up putting a clone of the root path string into the lua_ctx globals, which I can then use inside the lua function closure. The combined paths are a mix of separators which is wierd to me: `loading "../testapp\\background_sprites.png"`, they also seem to be relative from the system's path which i guess is ok. OK actually these paths are not working, I'll have to puzzle out how to combine them properly.

I am noticing my system setup is super slow to start up, need to dig into what's going on

# 10-20-2022

I now realize that loading the mixed paths was working correctly, but the retrieval by path key is still using the relative path. This is something that happens every draw command so I probably want to be a little picky about how I resolve this:

a) do the same path combining in the draw call, see if it's actually slow
b) do a simpler path concat
c) return a key in the load call (probably just a hash of the full path). I'd lose some ergonomics about using string literals without saving a reference in fennel
d) keep a resource hash on the App, then I could continue to use relative keys
e) keep a lookup table on the App for local->global keys

would be *really* helpfull if I could get access to the App struct inside the lua_ctx function calls

# 10-21-2022

I am considering switching dev back to `hlua` branch as the bindings are simpler and I could access the App struct.

# 10-23-2022

Brought `hlua` up to speed but the Lua struct requires a lifetime and I get into similar issues as 10 days ago. Not feeling great about how stalled I am with this.

# 10-24-2022

trying to pass `PathBuf::from(&path).as_path()` into my `App<'a>` is failing with "argument requires that borrow lasts for `'static`". I am confused because I thought the argument was not used in the struct itself (it's used to create a PathBuf). 
* I could try to use an owned pathbuf as an argument
* I could try to annotate the argument with a 'b lifetime

Ended up using PathBuf as the argument type and putting a lifetime on the App return value, everything seems to be working now so later tonight I should be able to get back to the global resource loading issue.

# 10-27-2022

Hi, last night I decided that there is no reasonable way to borrow the App struct inside it's lua function closures. I am going to either:
* set an active app mutex before any lua code execution
* stick the root path into lua and wrap the function calls to globalize the path

I desperately need to make *some* kind of progress here

# 10-28-2022

OK I've solved the relative paths thing by just using `env::current_dir()` everywhere.  Honestly this was very simple and I could have done this 10 days ago.

My next goal is calling a viable update() on a child process

# 10-29-2022

Upadate is working I'm sucessfully updating Jumpminster from the system process! Next I want to have processes get a UID so i can launch the same one multiple times

# 10-30-2022

How do apps commucate with the system app? There are some calls (quit, new_window, set_window, close_window)

Also, there is an issue with file reloading not knowing which app & path is proper.

I am working on reloading, which meant checking every app to see if it's root is a prefix of the changed file. The actual reload function is getting a relative path maybe, need to sort that out.

Ok reloading an app works but reloading the system app seems to fail by the launched app not loading it's images correctly.

# 11-01-2022

Thinking about communication between processes and the system app.  Ideally the 'children' can call some standard functions (quit, new_render_texture, etc.) handled by the system and not the rust environment.  This allows the system to manage windows, clean up, etc. 

My current plan: said functions will get ahold of the system app and call corresponding handlers, returning their returned values. My only worry is that the `system` app will be hard to access, but I can always store it under a special key.

Program is freezing up after I put system app into the `APPS` mutex, believe it's because of the lock. I will probably have to have a separate mutex for the system_process. (I did do that)

Ok and the real problem is in my bridging call i would need to access system, which was already locked in the loop to update.

# 11-03-2022

I took a 2 day detour trying to figure out how to get a raw pointer to my system app that i could use unsafely. It is working using an AtomicPtr! It should be easy to have apps call the system now, next steps are the quit functions.

[x] TODO The system app is loading children before it has `app` set on it's table, might want to have a `:start` or something

things are locking up when I try and close_process from the child.... ah wait I know the child was in a mutex and I'm trying to access it again in the `_close_process`. I'll need to free it in a later sweep

Another thought, apps will need to have ownership of their render textures.

[x] TODO Something is wrong with my reload paths, the system is trying to reload the testapp app.fnl (this explains why it wouldn't load textures earlier, I would never have figured this out without having some fns `quit` be not available in the system!) -- Turns out I was just missing the set working directory command on the system reload.

# 11-07-2022

Implemented `list_files`!  At some point I'm going to need to work on sandboxing, some thoughts on that: `list_files` should constrain the path to within the fen2 `files` dir.  I'll also want to ensure a root `/foo` parses as `files/foo`.  Lua's `io` module needs to be removed, although `io.open` needs to be wrapped in something that sanitizes it's path argument. 

Revisiting the render texture/window thing to see if this can be a bit simpler:

system:

  `create_render_texture() -> uid`
  `free_render_texture(uid)`
  `set_render_texture(uid)`
  `draw_render_texture(uid)`

apps:

   `new_window(w, h, title) -> render_texture_id`
   `close_window(render_texture_id)`
   `set_window(render_texture_id)` activates the render texture and camera
   `window_size(render_texture_id) -> int, int` gets the `system` determined size of the window

Additionally there is an assumption that `uid` 0 is the main render texture, or for apps the primary window (well, should apps be allowed to run in headless mode?)

# 12-16-2024

Maybe picking this up again. Updated macroquad dep for new rust version and trying to fix a few borrow checker issues. Stuck with borrow issues with the render texture that wants to be passed to the camera2d.  Have to brush up on macroquad to remember why I need a camera at all, the examples don't seem to use one?

ok weird I just put a clone() in `render_cam.render_target = Some(render.clone());` per some examples on macroquad docs, why does that work.

Part of me wants to look into redoing this project with C and SDL or maybe raylib.  Apart from fighting the borrow checker there was problems with my builds not linking to libc correctly for some people AFAIK, and it was a known issue with rust executables

# 3-5-2025

Back in this codebase. Ostensibly toying with making a roguelike for 7drl but probably just going to poke at fen2.

It seems redraw clear happens every frame, this should be explicit! Added a clear_screen function to facilitate this.  Only issue is that my `system` app switches between other apps which might not know they need to be redrawn.

In early journal notes I discuss having render textures assigned to apps. That would avoid this problem because the textures would persist. (a lot of implementation work though). I'd want to call lua functions when those textures were resized anyway.

I could hard code a `app_focused` function between lua processes.. not what I want.

I could set up some sort of inter-process message passing.. would payload have to passed through rust?


when you save a file the main app.fnl doesn't rerun, but during developing for fen2 i feel it should