#[macro_use]
extern crate lazy_static;
use hlua::Lua;
use macroquad::prelude::*;
use std::fs::File;
use std::path::Path;
use std::sync::Mutex;

lazy_static! {
    static ref IMAGE: Mutex<Image> = Mutex::new(Image::gen_image_color(
        screen_width() as u16,
        screen_height() as u16,
        BLACK
    ));
}

struct App<'a> {
    lua: Lua<'a>,
}

impl<'a> App<'a> {
    fn new() -> App<'a> {
        let mut lua = Lua::new();
        lua.openlibs();
        lua.set("set_pixel", hlua::function3(set_pixel));
        println!(
            "{:?} require",
            lua.execute::<()>("fennel = require(\"fennel\")").unwrap()
        );
        App { lua: lua }
    }
}

fn window_conf() -> Conf {
    Conf {
        window_title: "FEN2".to_owned(),
        window_width: 640,
        window_height: 480,
        ..Default::default()
    }
}

fn set_pixel(x: u32, y: u32, c: bool) {
    IMAGE
        .lock()
        .unwrap()
        .set_pixel(x, y, if c { BLACK } else { WHITE });
}

#[macroquad::main(window_conf)]
async fn main() {
    let texture = Texture2D::from_image(&*IMAGE.lock().unwrap());
    let mut app = App::new();
    loop {
        clear_background(WHITE);

        app.lua
            .execute::<()>(
                "fennel.eval(\" (for [x 10 300] (for [y 10 300]  (if (= (% x y) 0) (set_pixel x y false)))) \")",
            )
            .unwrap();
        texture.update(&*IMAGE.lock().unwrap());

        draw_texture(texture, 0., 0., WHITE);

        next_frame().await
    }
}
