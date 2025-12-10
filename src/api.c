
#include <lua.h>
static int _quit(lua_State *L){
    current_app->queue_destroy = true;
}

static int _list_files(lua_State *L){
    const char *path = lua_tostring(L, 1);
    lua_newtable(L);
    DIR *dir = opendir(path);
    if (!dir) {
        lua_pushstring(L, "error opening directory");
        return 1;
    }
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        /* path for stat */
        char full_path[PATH_MAX];
        snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);

        struct stat statbuf;
        if (stat(full_path, &statbuf) == 0) {
            const char *type;
            if (S_ISDIR(statbuf.st_mode)) {
                type = "dir";
            } else if (S_ISREG(statbuf.st_mode)) {
                type = "file";
            } else {
                continue;
            }
            lua_pushstring(L, entry->d_name);
            lua_pushstring(L, type);
            lua_settable(L, -3);
        }
    }
    closedir(dir);
    return 1;
}

static int _clear_screen(lua_State *L){
    const bool c = lua_toboolean(L, 1);
    set_bw_color(c);
    SDL_RenderClear(renderer);
    return 0;
}

static int _load_sound(lua_State *L){
    const char *path = lua_tostring(L, 1);
    return 0;
}

static int _play_sound(lua_State *L){
    const char *path = lua_tostring(L, 1);
    return 0;
}

static int _set_pixel(lua_State *L){
    const int x = lua_tointeger(L, 1);
    const int y = lua_tointeger(L, 2);
    const bool c = lua_toboolean(L, 3);
    set_bw_color(c);
    SDL_RenderPoint(renderer, x, y);
    return 0;
}

static int _draw_rect(lua_State *L){
    const int x = lua_tointeger(L, 1);
    const int y = lua_tointeger(L, 2);
    const int w = lua_tointeger(L, 3);
    const int h = lua_tointeger(L, 4);
    const bool c = lua_toboolean(L, 5);
    set_bw_color(c);
    SDL_FRect r = {x, y, w, h};
    SDL_RenderFillRect(renderer, &r);
    return 0;
}

static int _draw_rect_lines(lua_State *L){
    const int x = lua_tointeger(L, 1);
    const int y = lua_tointeger(L, 2);
    const int w = lua_tointeger(L, 3);
    const int h = lua_tointeger(L, 4);
    const bool c = lua_toboolean(L, 5);
    set_bw_color(c);
    SDL_FRect r = {x, y, w, h};
    SDL_RenderRect(renderer, &r);
    return 0;
}




static int _load_img(lua_State *L){
    const char *_img_path = lua_tostring(L, 1);
    char *img_path = strdup(_img_path);
    // check app.textures cache
    khint_t ck = kh_get(texture_cache, current_app->textures, img_path);
    if (ck != kh_end(current_app->textures)) {
        // Already cached, return existing texture
        return 0;
    }

    // https://examples.libsdl.org/SDL3/renderer/06-textures/
    char *full_path = NULL;
    SDL_Surface *surface = NULL;
    static SDL_Texture *texture = NULL;

    SDL_asprintf(&full_path, "%s%c%s", current_app->root, PATH_SEP, img_path);  /* allocate a string of the full file path */
    surface = SDL_LoadPNG(full_path);
    if (!surface) {
        SDL_Log("Couldn't load bitmap: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }


    SDL_free(full_path);  /* done with this, the file is loaded. */

    int texture_width = surface->w;
    int texture_height = surface->h;

    texture = SDL_CreateTextureFromSurface(renderer, surface);
    if (!texture) {
        SDL_Log("Couldn't create static texture: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST);

    int ret;
    khint_t k = kh_put(texture_cache, current_app->textures, img_path, &ret);
    kh_value(current_app->textures, k) = texture;

    SDL_DestroySurface(surface);  /* done with this, the texture has a copy of the pixels now. */

    return 0;
}

static int _draw_img(lua_State *L){
    const char *img_path = lua_tostring(L, 1);
    const double x = lua_tonumber(L, 2);
    const double y = lua_tonumber(L, 3);
    // check app.textures cache
    khint_t ck = kh_get(texture_cache, current_app->textures, img_path);
    if (ck == kh_end(current_app->textures)) {
        printf("Unable to draw_img, no image loaded for: %s", img_path);
        return 0;
    }
    SDL_Texture *texture = kh_value(current_app->textures, ck);
    SDL_FRect dest = {x, y, texture->w, texture->h};
    SDL_RenderTexture(renderer, texture, NULL, &dest);
    return 0;
}

static int _draw_sprite(lua_State *L){
    const char *img_path = lua_tostring(L, 1);
    const double x = lua_tonumber(L, 2);
    const double y = lua_tonumber(L, 3);
    const int sx = lua_tointeger(L, 4);
    const int sy = lua_tointeger(L, 5);
    const int sw = lua_tointeger(L, 6);
    const int sh = lua_tointeger(L, 7);
    // check app.textures cache
    khint_t ck = kh_get(texture_cache, current_app->textures, img_path);
    if (ck == kh_end(current_app->textures)) {
        printf("Unable to draw_sprite, no image loaded for: %s", img_path);
        return 0;
    }
    SDL_Texture *texture = kh_value(current_app->textures, ck);
    SDL_FRect srce = {sx, sy, sw, sh};
    SDL_FRect dest = {x, y, sw, sh};
    SDL_RenderTexture(renderer, texture, &srce, &dest);
return 0;
}

static int _draw_9patch(lua_State *L){
    const char *img_path = lua_tostring(L, 1);
    const int left_width = lua_tonumber(L, 2);
    const int right_width = lua_tonumber(L, 3);
    const int top_height = lua_tonumber(L, 4);
    const int bottom_height = lua_tonumber(L, 5);
    const double x = lua_tonumber(L, 6);
    const double y = lua_tonumber(L, 7);
    const double w = lua_tonumber(L, 8);
    const double h = lua_tonumber(L, 9);
    // check app.textures cache
    khint_t ck = kh_get(texture_cache, current_app->textures, img_path);
    if (ck == kh_end(current_app->textures)) {
        printf("Unable to draw_9patch, no image loaded for: %s", img_path);
        return 0;
    }
    SDL_Texture *texture = kh_value(current_app->textures, ck);
    SDL_FRect dest = {x, y, w, h};
    SDL_RenderTexture9GridTiled(renderer, texture, NULL, left_width, right_width, top_height, bottom_height, 0.0, &dest, 1.0);
    return 0;
}

static int _draw_rendertexture(lua_State *L){
    const int *img_key = lua_tointeger(L, 1);
    const double x = lua_tonumber(L, 2);
    const double y = lua_tonumber(L, 3);
    SDL_Texture *texture = app_get_rendertexture(current_app, img_key);
    if (texture == NULL) return 0;
    SDL_FRect dest = {x, y, texture->w, texture->h};
    SDL_RenderTexture(renderer, texture, NULL, &dest);
    return 0;
}

static int _draw_text(lua_State *L){
    const char *message = lua_tostring(L, 1);
    const int x = lua_tointeger(L, 2);
    const int y = lua_tointeger(L, 3);
    const bool c = lua_toboolean(L, 4);
    if (c) {
        SDL_SetTextureColorMod(default_font->texture, 0, 0, 0);
    } else {
        SDL_SetTextureColorMod(default_font->texture, 255, 255, 255);
    }
    draw_font_text(default_font, x, y, message);
    return 0;
}



static int _key_down(lua_State *L){
    const char *key = lua_tostring(L, 1);
    SDL_Scancode scancode = keycode(key);
    if (scancode == SDL_SCANCODE_UNKNOWN) {
        lua_pushboolean(L, false);
        return 1;
    }
    lua_pushboolean(L, current_keys[scancode]);
    return 1;
}

static int _key_pressed(lua_State *L){
    const char *key = lua_tostring(L, 1);
    SDL_Scancode scancode = keycode(key);

    if (scancode == SDL_SCANCODE_UNKNOWN) {
        lua_pushboolean(L, false);
        return 1;
    }
    lua_pushboolean(L, current_keys[scancode] && !previous_keys[scancode]);
    return 1;
}

static int _key_released(lua_State *L){
    const char *key = lua_tostring(L, 1);
    SDL_Scancode scancode = keycode(key);
    if (scancode == SDL_SCANCODE_UNKNOWN) {
        lua_pushboolean(L, false);
        return 1;
    }
    lua_pushboolean(L, !current_keys[scancode] && previous_keys[scancode]);
    return 1;
}

static int _mouse_pos(lua_State *L){
    const char *key = lua_tostring(L, 1);
    // TODO
    float x, y;
    SDL_GetMouseState(&x, &y);
    lua_pushnumber(L, x);
    lua_pushnumber(L, y);
    return 2;
}

static Uint32 get_mouse_mask(int button) {
    switch(button) {
        case 1: return SDL_BUTTON_LMASK;
        case 2: return SDL_BUTTON_MMASK;
        case 3: return SDL_BUTTON_RMASK;
        default: return 0;
    }
}

static int _mouse_down(lua_State *L){
    const int button = lua_tointeger(L, 1);
    Uint32 mask = get_mouse_mask(button);
    lua_pushboolean(L, current_mouse & mask);
    return 1;
}

static int _mouse_pressed(lua_State *L){
    const int button = lua_tointeger(L, 1);
    Uint32 mask = get_mouse_mask(button);
    lua_pushboolean(L, (current_mouse & mask) && !(previous_mouse & mask));
    return 1;
}

static int _mouse_released(lua_State *L){
    const int button = lua_tointeger(L, 1);
    Uint32 mask = get_mouse_mask(button);
    lua_pushboolean(L, !(current_mouse & mask) && (previous_mouse & mask));
    return 1;
}

static int _launch_process(lua_State *L){
    const char *path = lua_tostring(L, 1);

    // hack to remove "../" prefix
    const char *app_name = path;
    if (strncmp(path, "../", 3) == 0) {
        app_name = path + 3;
    }
    struct App * app = new_app(app_name, false);
    lua_pushinteger(L, app->id);
    return 1;
}

struct App* get_app(int id){
    khint_t app_key = kh_get(app_cache, apps, id);
    if (app_key != kh_end(apps)) {
        return kh_value(apps, app_key);
    } else {
        return NULL;
    }
}

static int _update_process(lua_State *L){
    const int id = lua_tointeger(L, 1);
    struct App * app = get_app(id);
    if (app != NULL) {
        app_update(app);
        app_set_cwd(system_app);
    }
    return 1;
}

static int _close_process(lua_State *L){
    const int id = lua_tointeger(L, 1);
    struct App * app = get_app(id);
    if (app != NULL) {
        app->queue_destroy = true;
    }
    return 0;
}

// TODO I probably want to return booleans from these rendertextures regarding the existance of the texture

static int _draw_app_rendertexture(lua_State *L){
    const int id = lua_tointeger(L, 1);
    const int *img_key = lua_tointeger(L, 2);
    const double x = lua_tonumber(L, 3);
    const double y = lua_tonumber(L, 4);
    struct App * app = get_app(id);
    SDL_Texture *texture = app_get_rendertexture(current_app, img_key);
    if (app != NULL && texture != NULL) {
        SDL_FRect dest = {x, y, texture->w, texture->h};
        SDL_RenderTexture(renderer, texture, NULL, &dest);
    }
    return 0;
}
