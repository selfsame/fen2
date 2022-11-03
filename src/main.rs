#[macro_use]
extern crate lazy_static;
use hlua::{Lua, LuaError};
use macroquad::audio::{load_sound, play_sound, play_sound_once, PlaySoundParams, Sound};
use macroquad::prelude::*;
use std::collections::{HashMap, HashSet};
use std::env;
use std::ffi::OsStr;
use std::fs::File;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Mutex;
use rand;
use notify::{watcher, RecursiveMode, Watcher};
use std::sync::mpsc::channel;
use std::time::{Duration, Instant, SystemTime};
use std::ptr;
use std::sync::atomic::{AtomicPtr, Ordering};
use std::mem::{self, MaybeUninit};

mod keys;

lazy_static! {
    static ref BASE_PATH: PathBuf = env::current_dir().unwrap();
    static ref IMAGE: Mutex<Image> = Mutex::new(Image::gen_image_color(
        screen_width() as u16,
        screen_height() as u16,
        BLACK
    ));
    static ref SYS_PTR: AtomicPtr<App<'static>> = AtomicPtr::new(unsafe {mem::zeroed()});
    static ref APPS: Mutex<HashMap<String, Mutex<App<'static>>>> = Mutex::new(HashMap::new());
    static ref TO_REMOVE_APPS: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
    static ref FONTS: Mutex<HashMap<String, Font>> = Mutex::new(HashMap::new());
    static ref TEXTURES: Mutex<HashMap<String, Texture2D>> = Mutex::new(HashMap::new());
    static ref UNLOADED_TEXTURES: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
    static ref SOUNDS: Mutex<HashMap<String, Sound>> = Mutex::new(HashMap::new());
    static ref UNLOADED_SOUNDS: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
    static ref MOUSE: Mutex<(f32, f32)> = Mutex::new((0., 0.));
}

fn window_conf() -> Conf {
    Conf {
        window_title: "FEN2".to_owned(),
        window_width: 640,
        window_height: 480,
        ..Default::default()
    }
}


fn system_app_pointer() -> *mut App<'static> {
    //let mut A = SYSTEM_APP_PTR.lock().unwrap();
    //let b = *A.get_mut();
    //b
    let b = SYS_PTR.load(Ordering::Relaxed);
    b
}

fn globalize_path_string(path:&str) -> String {
    env::current_dir().unwrap().join(path).into_os_string().into_string().unwrap()
}

// user code will load images into the TEXTURES dict by path name
async fn _preload_texture(path: String, reload: bool) -> bool {
    let mut textures = TEXTURES.lock().unwrap();

    let p = &path;
    if reload || !textures.contains_key(p) {
        match load_texture(p).await {
            Ok(t) => {
                textures.insert(path, t);
                return true;
            }
            Err(e) => {
                println!("{:?}", e);
                return false;
            }
        }
    } else {
        return true;
    }
}

async fn _handle_unloaded_textures() {
    for s in UNLOADED_TEXTURES.lock().unwrap().drain() {
        println!("loading {:?}", s);
        _preload_texture(s, false).await;
    }
}

fn _preload_texture_sync(path: String) {
    UNLOADED_TEXTURES.lock().unwrap().insert(path);
}

async fn _preload_sound(path: String, reload: bool) -> bool {
    let mut sounds = SOUNDS.lock().unwrap();

    let p = &path;
    if reload || !sounds.contains_key(p) {
        match load_sound(p).await {
            Ok(t) => {
                sounds.insert(path, t);
                return true;
            }
            Err(e) => {
                println!("{:?}", e);
                return false;
            }
        }
    } else {
        return true;
    }
}

async fn _handle_unloaded_sounds() {
    for s in UNLOADED_SOUNDS.lock().unwrap().drain() {
        println!("loading {:?}", s);
        _preload_sound(s, false).await;
    }
}

fn _preload_sound_sync(path: String) {
    UNLOADED_SOUNDS.lock().unwrap().insert(path);
}

fn _play_sound(path: String, looped: bool, volume: f32) {
    let sounds = SOUNDS.lock().unwrap();
    match sounds.get(&globalize_path_string(&path)) {
        Some(t) => play_sound(
            *t,
            PlaySoundParams {
                looped: looped,
                volume: volume,
            },
        ),
        None => println!("Error: no sound {}", &path),
    }
}

fn _draw_texture(path: String, x: u32, y: u32) {
    

    let textures = TEXTURES.lock().unwrap();
    match textures.get(&globalize_path_string(&path)) {
        Some(t) => draw_texture(*t, x as f32, y as f32, WHITE),
        None => println!("Error: no texture {}", &path),
    }
}

fn _draw_texture_ex(path: String, x: u32, y: u32, sx: u32, sy: u32, sw: u32, sh: u32) {
    let textures = TEXTURES.lock().unwrap();
    match textures.get(&globalize_path_string(&path)) {
        Some(t) => draw_texture_ex(
            *t,
            x as f32,
            y as f32,
            WHITE,
            DrawTextureParams {
                source: Some(Rect {
                    x: sx as f32,
                    y: sy as f32,
                    w: sw as f32,
                    h: sh as f32,
                }),
                ..Default::default()
            },
        ),
        None => println!("Error: no texture {}", &path),
    }
}

fn set_pixel(x: u32, y: u32, c: bool) {
    IMAGE
        .lock()
        .unwrap()
        .set_pixel(x, y, if c { BLACK } else { WHITE });
}

fn draw_text(s: String, x: u32, y: u32, c: bool) {
    let font = *FONTS
        .lock()
        .unwrap()
        .get(&String::from("HelvetiPixel"))
        .unwrap();
    draw_text_ex(
        &s,
        x as f32,
        y as f32,
        TextParams {
            font: font,
            font_size: 16,
            font_scale: 1.0,
            font_scale_aspect: 1.0,
            color: if c { BLACK } else { WHITE },
            ..Default::default()
        },
    );
}

fn _draw_rect(x: u32, y: u32, w: u32, h: u32, c: bool) {
    draw_rectangle(
        x as f32,
        y as f32,
        w as f32,
        h as f32,
        if c { BLACK } else { WHITE },
    );
}

fn _draw_rect_lines(x: u32, y: u32, w: u32, h: u32, thickness: u32, c: bool) {
    draw_rectangle_lines(
        x as f32,
        y as f32,
        w as f32,
        h as f32,
        (thickness * 2) as f32,
        if c { BLACK } else { WHITE },
    );
}

fn int_to_button(i: i32) -> MouseButton {
    match i {
        0 => MouseButton::Right,
        1 => MouseButton::Left,
        2 => MouseButton::Middle,
        _ => MouseButton::Unknown,
    }
}

fn _mouse_pos() -> (i32, i32) {
    let (x, y) = *MOUSE.lock().unwrap();
    return (x as i32, y as i32);
}

fn _mouse_down(btn: i32) -> bool {
    return is_mouse_button_down(int_to_button(btn));
}

fn _mouse_pressed(btn: i32) -> bool {
    return is_mouse_button_pressed(int_to_button(btn));
}

fn _mouse_released(btn: i32) -> bool {
    return is_mouse_button_released(int_to_button(btn));
}

fn _key_down(key: String) -> bool {
    return is_key_down(keys::keycode(&key));
}

fn _key_pressed(key: String) -> bool {
    return is_key_pressed(keys::keycode(&key));
}

fn _key_released(key: String) -> bool {
    return is_key_released(keys::keycode(&key));
}


// System bindings

fn _launch_process(path: String) -> String {
    let id = rand::rand();
    let mut app = App::new(PathBuf::from(&path), id.to_string(), false);
    app.init();
    APPS.lock().unwrap().insert(id.to_string(), Mutex::new(app));
    return id.to_string();
}

fn _update_process(id: String, dt:f64) {
    let apps = APPS.lock().unwrap();
    
    match apps.get(&id.clone()) {
        Some(app) => {
            let mut app = app.lock().unwrap();
            app.set_working_directory();
            app.update(dt);
        }
        None => {
            ()
        }
    }
}

fn _close_process(id: String) {
    TO_REMOVE_APPS.lock().unwrap().insert(id);
}

fn _remove_closed_processes() {
    for s in TO_REMOVE_APPS.lock().unwrap().drain() {
        let mut apps = APPS.lock().unwrap();
        match apps.remove(&s.clone()) {
            Some(_) => {
                println!("removing app id {:?}", &s);
            }
            None => {
                ()
            }
        }
    }
}


fn print_lua_error(e: &LuaError) {
    match e {
        LuaError::ExecutionError(s) => {
            for s in format!("{:?}", e).split("\\n") {
                println!("{}", s)
            }
        }
        other => println!("{:?}", other),
    }
}

struct App<'a> {
    id: String,
    root: PathBuf,
    lua: Lua<'a>,
    is_system: bool
}

impl<'a> App<'a> {
    fn new(root: PathBuf, id: String, is_system: bool) -> App<'a> {
        env::set_current_dir(&root).unwrap();
        let lua = Lua::new();
        
        App {
            lua: lua,
            id: id,
            root: root,
            is_system: is_system
        }
    }

    fn init(&mut self) {
        self.lua.openlibs();
        self.lua.set("_root_path", self.root.clone().into_os_string().into_string().unwrap());
        
        // system bindings
        if self.is_system {
            self.lua.set("launch_process", hlua::function1(_launch_process));
            self.lua.set("update_process", hlua::function2(_update_process));
            self.lua.set("close_process", hlua::function1(_close_process));
        }

        // app <-> system bridges
        if !self.is_system {
            let myid = self.id.clone();
            
            self.lua.set("quit", hlua::function0(move || {
                unsafe {
                    let sptr = system_app_pointer();
                    let sys = &mut *sptr;
                    sys.lua.execute::<()>(&format!("app.handle_quit({:?})", myid)).unwrap();
                }
            }));
        }


        self.lua.set("load_img", hlua::function1(|path: String| {
            _preload_texture_sync(globalize_path_string(&path));
        }));
        self.lua.set("load_sound", hlua::function1(|path: String| {
            _preload_sound_sync(globalize_path_string(&path));
        }));


        self.lua.set("set_pixel", hlua::function3(set_pixel));
        
        self.lua.set("draw_img", hlua::function3(_draw_texture));
        self.lua.set("draw_sprite", hlua::function7(_draw_texture_ex));

        self.lua.set("draw_rect", hlua::function5(_draw_rect));
        self.lua.set("draw_rect_lines", hlua::function6(_draw_rect_lines));

        self.lua.set("draw_text", hlua::function4(draw_text));

        self.lua.set("play_sound", hlua::function3(_play_sound));

        self.lua.set("show_mouse", hlua::function1(show_mouse));
        self.lua.set("mouse_pos", hlua::function0(_mouse_pos));
        self.lua.set("mouse_down", hlua::function1(_mouse_down));
        self.lua.set("mouse_pressed", hlua::function1(_mouse_pressed));
        self.lua.set("mouse_released", hlua::function1(_mouse_released));
        self.lua.set("key_down", hlua::function1(_key_down));
        self.lua.set("key_pressed", hlua::function1(_key_pressed));
        self.lua.set("key_released", hlua::function1(_key_released));

        // both package.path and fennel.path use '?' as wildcard
        let mut base_copy = BASE_PATH.clone();
        base_copy.push("?");

        self.lua.execute::<()>(
            std::format!(
                "package.path = package.path .. ';{}.lua'",
                str::replace(base_copy.to_str().unwrap(), "\\", "\\\\")
            )
            .as_str(),
        )
        .unwrap();

        self.lua.execute::<()>("fennel = require('fennel')").unwrap();
        self.lua.execute::<()>("table.insert(package.loaders or package.searchers, fennel.searcher)")
            .unwrap();

            self.lua.execute::<()>(
            std::format!(
                "fennel.path = fennel.path .. ';{}.fnl'",
                str::replace(base_copy.to_str().unwrap(), "\\", "\\\\")
            )
            .as_str(),
        )
        .unwrap();

        self.lua.execute::<()>("reloader = require('reloader')").unwrap();

        match self.lua.execute::<()>("app = require(\"app\")") {
            Err(e) => print_lua_error(&e),
            res => res.unwrap(),
        }

    }

    fn set_working_directory(&self) {
        env::set_current_dir(&self.root).unwrap();
    }

    fn root_is_prefix_of(&self, path: &Path) -> bool {
        path.canonicalize().unwrap().starts_with(self.root.canonicalize().unwrap())
    }

    async fn reload(&mut self, path: PathBuf) {
        let path_s = path.to_str().unwrap();
        let root_s = self.root.to_str().unwrap();
        let mime = path.extension().and_then(OsStr::to_str);
        // reload! "C:\\dev\\rust\\fen2\\files\\testapp\\app.fnl" "../testapp" None
        println!("reload! {:?} {:?} {:?}", path_s, root_s, path_s.strip_prefix(root_s));
        // strip the app's root
        match path.canonicalize().unwrap().to_str().unwrap().strip_prefix(self.root.canonicalize().unwrap().to_str().unwrap()) {
            Some(_s) => {
                let s = _s.strip_prefix(&"\\").unwrap_or(_s);
                println!("{:?} changed", s);
                println!("app is {:?}", self.root);
                match mime {
                    Some("png") | Some("bmp") => {
                        _preload_texture(path_s.to_string(), true).await;
                    }
                    Some("lua") | Some("fnl") => {
                        println!("reload_path {:?}", s);
                        match &self
                            .lua
                            .execute::<()>(&format!("reloader.reload_path({:?})", s))
                        {
                            Err(e) => print_lua_error(e),
                            _ => (),
                        }
                        // use the normal require to update our `app` binding
                        match &self.lua.execute::<()>("app = require(\"app\")") {
                            Err(e) => print_lua_error(e),
                            _ => (),
                        }
                    }
                    _ => (),
                }
            }
            None => (),
        }
    }
    fn update(&mut self, dt: f64) {
        match &self
            .lua
            .execute::<()>(&format!("if app.update then app.update({}) end", dt))
        {
            Err(e) => print_lua_error(e),
            _ => (),
        }
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    // we'll time our own delta time
    let instant = Instant::now();
    let mut elapsed = instant.elapsed().as_secs_f64();

    let (tx, rx) = channel();
    let mut watcher = watcher(tx, Duration::from_millis(100)).unwrap();
    watcher.watch("files", RecursiveMode::Recursive).unwrap();

    FONTS.lock().unwrap().insert(
        String::from("HelvetiPixel"),
        load_ttf_font("./HelvetiPixel.ttf").await.unwrap(),
    );

    let mut app_root = BASE_PATH.clone();
    app_root.push("files");
    app_root.push("system");
    let mut system_app = App::new(app_root, String::from("system"), true);
    let sa_ptr: *mut App = &mut system_app;
    SYS_PTR.store(sa_ptr, Ordering::Relaxed);
    system_app.init();

    let render = render_target(640, 480);
    render.texture.set_filter(FilterMode::Nearest);
    let mut render_cam = Camera2D::from_display_rect(Rect {
        x: 0.,
        y: 0.,
        w: 640.,
        h: 480.,
    });

    render_cam.render_target = Some(render);
    render_cam.zoom.y = render_cam.zoom.y * -1.;

    loop {
        let (width, height, scale) = if screen_width() >= 1280. && screen_height() >= 960. {
            (1280., 960., 2.)
        } else if screen_width() >= 640. && screen_height() >= 480. {
            (640., 480., 1.)
        } else {
            (320., 240., 0.5)
        };
        let (mx, my) = mouse_position();

        *MOUSE.lock().unwrap() = (
            ((mx - ((screen_width() - width) * 0.5)) / scale).round(),
            ((my - ((screen_height() - height) * 0.5)) / scale).round(),
        );

        set_camera(&render_cam);

        system_app.set_working_directory();
        _handle_unloaded_textures().await;
        _handle_unloaded_sounds().await;
        clear_background(WHITE);

        let dt = instant.elapsed().as_secs_f64() - elapsed;
        elapsed = instant.elapsed().as_secs_f64();

        system_app.update(dt);



        //texture.update(&*IMAGE.lock().unwrap());
        //draw_texture(texture, 0., 0., WHITE);

        set_default_camera();
        clear_background(BLACK);

        draw_texture_ex(
            render.texture,
            ((screen_width() - width) / 2.).floor(),
            ((screen_height() - height) / 2.).floor(),
            WHITE,
            DrawTextureParams {
                dest_size: Some(vec2(width, height)),
                ..Default::default()
            },
        );

        // need to find all apps that have a matching root prefix to the reload path and
        // call reload on them.
        match rx.try_recv() {
            Ok(notify::DebouncedEvent::NoticeWrite(path)) => {
                println!("notify {:?}", path);
                let apps = APPS.lock().unwrap();
                for value in apps.values() {
                    let mut a = value.lock().unwrap();
                    
                    if a.root_is_prefix_of(&path) {
                        
                        a.set_working_directory();
                        a.reload(path.clone()).await;
                    }
                }
            
                if system_app.root_is_prefix_of(path.as_path()) {
                    system_app.reload(path).await;
                }
            }
            Err(_e) => (),
            _ => (),
        }

        env::set_current_dir(BASE_PATH.clone()).unwrap();

        _remove_closed_processes();

        next_frame().await
    }
}
