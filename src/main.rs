#[macro_use]
extern crate lazy_static;
use hlua::{Lua, LuaError};
use macroquad::prelude::*;
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs::File;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Mutex;

use notify::{watcher, RecursiveMode, Watcher};
use std::sync::mpsc::channel;
use std::time::{Duration, Instant, SystemTime};

lazy_static! {
    static ref BASE_PATH: PathBuf = env::current_dir().unwrap();
    static ref IMAGE: Mutex<Image> = Mutex::new(Image::gen_image_color(
        screen_width() as u16,
        screen_height() as u16,
        BLACK
    ));
    static ref FONTS: Mutex<HashMap<String, Font>> = Mutex::new(HashMap::new());
    static ref TEXTURES: Mutex<HashMap<String, Texture2D>> = Mutex::new(HashMap::new());
    static ref UNLOADED_TEXTURES: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
}

fn window_conf() -> Conf {
    Conf {
        window_title: "FEN2".to_owned(),
        window_width: 640,
        window_height: 480,
        ..Default::default()
    }
}

// user code will load images into the TEXTURES dict by path name
async fn _preload_texture(path: String) -> bool {
    let mut textures = TEXTURES.lock().unwrap();

    let p = &path;
    if !textures.contains_key(p) {
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
        _preload_texture(s).await;
    }
}

fn _preload_texture_sync(path: String) {
    UNLOADED_TEXTURES.lock().unwrap().insert(path);
}

fn _draw_texture(path: String, x: u32, y: u32) {
    let textures = TEXTURES.lock().unwrap();
    match textures.get(&path) {
        Some(t) => draw_texture(*t, x as f32, y as f32, WHITE),
        None => println!("Error: no texture {}", &path),
    }
}

fn _draw_texture_ex(path: String, x: u32, y: u32, sx: u32, sy: u32, sw: u32, sh: u32) {
    let textures = TEXTURES.lock().unwrap();
    match textures.get(&path) {
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
    let (x, y) = mouse_position();
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
    root: &'a Path,
    lua: Lua<'a>,
}

impl<'a> App<'a> {
    fn new(root: &'a Path) -> App<'a> {
        env::set_current_dir(&root).unwrap();
        let mut lua = Lua::new();
        lua.openlibs();
        lua.set("set_pixel", hlua::function3(set_pixel));
        lua.set("draw_text", hlua::function4(draw_text));
        lua.set("load_img", hlua::function1(_preload_texture_sync));
        lua.set("draw_img", hlua::function3(_draw_texture));
        lua.set("draw_sprite", hlua::function7(_draw_texture_ex));

        lua.set("draw_rect", hlua::function5(_draw_rect));
        lua.set("draw_rect_lines", hlua::function6(_draw_rect_lines));

        lua.set("show_mouse", hlua::function1(show_mouse));
        lua.set("mouse_pos", hlua::function0(_mouse_pos));
        lua.set("mouse_down", hlua::function1(_mouse_down));
        lua.set("mouse_pressed", hlua::function1(_mouse_pressed));
        lua.set("mouse_released", hlua::function1(_mouse_released));

        lua.execute::<()>("print(package.path)").unwrap();

        // both package.path and fennel.path use '?' as wildcard
        let mut base_copy = BASE_PATH.clone();
        base_copy.push("?");

        lua.execute::<()>(
            std::format!(
                "package.path = package.path .. ';{}.lua'",
                str::replace(base_copy.to_str().unwrap(), "\\", "\\\\")
            )
            .as_str(),
        )
        .unwrap();

        lua.execute::<()>("fennel = require('fennel')").unwrap();
        lua.execute::<()>("table.insert(package.loaders or package.searchers, fennel.searcher)")
            .unwrap();

        lua.execute::<()>(
            std::format!(
                "fennel.path = fennel.path .. ';{}.fnl'",
                str::replace(base_copy.to_str().unwrap(), "\\", "\\\\")
            )
            .as_str(),
        )
        .unwrap();

        lua.execute::<()>("system = require('system')").unwrap();

        match lua.execute::<()>("app = require(\"app\")") {
            Err(e) => print_lua_error(&e),
            res => res.unwrap(),
        }

        App {
            lua: lua,
            root: root,
        }
    }
    fn set_working_directory(&self) {
        env::set_current_dir(&self.root).unwrap();
    }
    fn reload(&mut self, path: PathBuf) {
        // I'll want to test path against the app root here
        // also check mime type is .fnl or .lua
        let path_s = path.to_str().unwrap();
        let root_s = self.root.to_str().unwrap();
        match path_s.strip_prefix(root_s) {
            Some(s) => {
                match &self
                    .lua
                    .execute::<()>(&format!("system.reload_path({:?})", s))
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

    let texture = Texture2D::from_image(&*IMAGE.lock().unwrap());

    // eventually we'll scan for available apps
    let mut app_root = BASE_PATH.clone();
    app_root.push("files");
    app_root.push("testapp");
    let mut app = App::new(app_root.as_path());

    loop {
        app.set_working_directory();
        _handle_unloaded_textures().await;
        clear_background(WHITE);

        let dt = instant.elapsed().as_secs_f64() - elapsed;
        elapsed = instant.elapsed().as_secs_f64();

        app.update(dt);

        //texture.update(&*IMAGE.lock().unwrap());
        //draw_texture(texture, 0., 0., WHITE);

        match rx.try_recv() {
            Ok(notify::DebouncedEvent::NoticeWrite(path)) => {
                app.reload(path);
            }
            Err(e) => (),
            _ => (),
        }

        env::set_current_dir(BASE_PATH.clone()).unwrap();

        next_frame().await
    }
}
