
#include "SDL3/SDL_render.h"
#include "SDL3/SDL_timer.h"
#include <linux/limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <khash.h>
#define SDL_MAIN_USE_CALLBACKS 1  /* use the callbacks instead of main() */
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#ifdef _WIN32
    #include <direct.h>
    #define chdir _chdir
    #define PATH_SEP '\\'
#else
    #include <unistd.h>
    #define PATH_SEP '/'
#endif
#include <dirent.h>
#include <sys/stat.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "keys.h"

KHASH_MAP_INIT_STR(texture_cache, SDL_Texture*)
KHASH_MAP_INIT_INT(app_cache, struct App*)

const char *base_path = NULL;

static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

static kh_app_cache_t *apps = NULL;

static struct App *system_app = NULL;

/* pointer to the app that is evaluating code */
static struct App *current_app = NULL;

/* forward declaration */
struct App * new_app(char path[], bool is_system);

int CUID = 0;
int uid(){
    CUID += 1;
    return CUID;
}

Uint64 last_timestamp = 0;
double delta = 0;

static Uint32 current_mouse = 0;
static Uint32 previous_mouse = 0;

static void update_mouse_states() {
    previous_mouse = current_mouse;
    float x, y;
    current_mouse = SDL_GetMouseState(&x, &y);
}

static Uint8 current_keys[SDL_SCANCODE_COUNT] = {0};
static Uint8 previous_keys[SDL_SCANCODE_COUNT] = {0};

static void update_key_states() {
    memcpy(previous_keys, current_keys, sizeof(current_keys));
    const Uint8 *state = SDL_GetKeyboardState(NULL);
    memcpy(current_keys, state, sizeof(current_keys));
}

struct App {
    int id;
    char root[PATH_MAX];
    lua_State *lua;
    bool is_system;
    khash_t(texture_cache) *textures;
    bool queue_destroy;
};

static void set_bw_color(bool c){
    if (c) {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    } else {
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    }
}


void app_set_cwd(struct App *app){
    if (chdir(app->root) != 0) {
        printf("Failed to change to app directory: %s\n", app->root);
    }
}

void app_eval(struct App *app, char *s){
    current_app = app;
    app_set_cwd(app);
    if (luaL_loadstring(app->lua, s) == LUA_OK) {
        if (lua_pcall(app->lua, 0, 0, 0) != LUA_OK) {
            // Handle error
            printf("Lua error: %s\n", lua_tostring(app->lua, -1));
        }
    } else {
        // Handle loading error
        printf("Lua loading error: %s\n", lua_tostring(app->lua, -1));
    }
}

void app_update(struct App *app){
    char buffer[60];
    sprintf(buffer, "if app and app.update then app.update(%f) end", delta);
    app_eval(app, buffer);
}

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
        // Already cached, return existing texture
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
        // Already cached, return existing texture
        printf("Unable to draw_img, no image loaded for: %s", img_path);
        return 0;
    }
    SDL_Texture *texture = kh_value(current_app->textures, ck);
    SDL_FRect srce = {sx, sy, sw, sh};
    SDL_FRect dest = {x, y, sw, sh};
    SDL_RenderTexture(renderer, texture, &srce, &dest);
return 0;
}

static int _draw_text(lua_State *L){
    const char *message = lua_tostring(L, 1);
    const int x = lua_tointeger(L, 2);
    const int y = lua_tointeger(L, 3);
    const bool c = lua_toboolean(L, 4);
    set_bw_color(c);
    // x = ((w / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE * SDL_strlen(message)) / 2;
    // y = ((h / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE) / 2;
    SDL_RenderDebugText(renderer, x, y, message);
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

static int _update_process(lua_State *L){
    const int id = lua_tointeger(L, 1);
    khint_t app_key = kh_get(app_cache, apps, id);
    if (app_key != kh_end(apps)) {
        struct App * app;
        app = kh_value(apps, app_key);
        app_update(app);
        app_set_cwd(system_app);
    }
    return 1;
}

static int _close_process(lua_State *L){
    const int id = lua_tointeger(L, 1);
    khint_t app_key = kh_get(app_cache, apps, id);
    if (app_key != kh_end(apps)) {
        struct App * app;
        app = kh_value(apps, app_key);
        app->queue_destroy = true;
    }
    return 0;
}



struct App * new_app(char path[], bool is_system){
    struct App *app = malloc(sizeof(struct App));

    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_openlibs(L);             // Open standard libraries

    lua_register(L, "quit", _quit);
    lua_register(L, "list_files", _list_files);
    lua_register(L, "clear_screen", _clear_screen);
    lua_register(L, "load_sound", _load_sound);
    lua_register(L, "play_sound", _play_sound);
    lua_register(L, "load_img", _load_img);
    lua_register(L, "draw_img", _draw_img);
    lua_register(L, "draw_sprite", _draw_sprite);
    lua_register(L, "draw_text", _draw_text);
    lua_register(L, "set_pixel", _set_pixel);
    lua_register(L, "draw_rect", _draw_rect);
    lua_register(L, "draw_rect_lines", _draw_rect_lines);

    lua_register(L, "mouse_pos", _mouse_pos);


    lua_register(L, "mouse_pressed", _mouse_pressed);
    lua_register(L, "mouse_down", _mouse_down);
    lua_register(L, "mouse_released", _mouse_released);

    lua_register(L, "key_pressed", _key_pressed);
    lua_register(L, "key_down", _key_down);
    lua_register(L, "key_released", _key_released);

    /* System */
    if (is_system) {
        lua_register(L, "launch_process", _launch_process);
        lua_register(L, "update_process", _update_process);
        lua_register(L, "close_process", _close_process);
    }


    app->id = uid();
    app->lua = L;
    app->is_system = is_system;
    app->textures = kh_init(texture_cache);
    app->queue_destroy = false;

    char app_path[PATH_MAX];
    snprintf(app_path, sizeof(app_path), "%sfiles%c%s", base_path, PATH_SEP, path);

    strncpy(app->root, app_path, PATH_MAX - 1);
    printf("app.root: %s\n", app->root);

    /* register app in the apps cache by id */
    int ret;
    khint_t k = kh_put(app_cache, apps, app->id, &ret);
    kh_value(apps, k) = app;


    app_set_cwd(app);

    char package_path[PATH_MAX * 2];
    char fennel_path[PATH_MAX * 2];

    snprintf(package_path, sizeof(package_path),
                "package.path = package.path .. ';%s/?.lua'", base_path);
    snprintf(fennel_path, sizeof(fennel_path),
                "fennel.path = fennel.path .. ';%s/?.fnl'", base_path);

    app_eval(app, package_path);
    app_eval(app, "fennel = require('fennel')");
    app_eval(app, "table.insert(package.loaders or package.searchers, fennel.searcher)");
    app_eval(app, fennel_path);
    app_eval(app, "reloader = require('reloader')");
    app_eval(app, "app = require(\"app\")");
    app_eval(app, "if app.start then app.start() end");

    return app;
}

void app_destroy(struct App *app){
    printf("destroying app: %s\n", app->root);
    bool is_system = app->is_system;
    khint_t k;
    for (k = kh_begin(app->textures); k != kh_end(app->textures); ++k) {
        if (kh_exist(app->textures, k)) {
            SDL_Texture *texture = kh_val(app->textures, k);
            SDL_DestroyTexture(texture);
        }
    }
    kh_destroy(texture_cache, app->textures);
    if (app->lua) lua_close(app->lua);
    khint_t app_key = kh_get(app_cache, apps, app->id);
    if (app_key != kh_end(apps)) {
        kh_del(app_cache, apps, app_key);
    }
    free(app);
    if (is_system) exit(0);
}

void Fen2Init(){
    apps = kh_init(app_cache);
    base_path = SDL_GetBasePath();
    printf("Base path: %s\n", base_path);
    system_app = new_app("system", true);
    printf("App id: %d, path: %s\n", system_app->id, system_app->root);
}

/* This function runs once at startup. */
SDL_AppResult SDL_AppInit(void **appstate, int argc, char *argv[])
{
    /* Create the window */
    if (!SDL_CreateWindowAndRenderer("Fen2", 640, 480, NULL, &window, &renderer)) {
        SDL_Log("Couldn't create window and renderer: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }
    SDL_SetRenderVSync(renderer, 1);

    Fen2Init();
    last_timestamp = SDL_GetPerformanceCounter();

    return SDL_APP_CONTINUE;
}

/* This function runs when a new event (mouse input, keypresses, etc) occurs. */
SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event)
{
    if (event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS;  /* end the program, reporting success to the OS. */
    }
    return SDL_APP_CONTINUE;
}

/* This function runs once per frame, and is the heart of the program. */
SDL_AppResult SDL_AppIterate(void *appstate)
{
    Uint64 now = SDL_GetPerformanceCounter();
    delta = (double)(now - last_timestamp) / SDL_GetPerformanceFrequency();
    last_timestamp = now;

    update_mouse_states();
    update_key_states();

    // int w = 0, h = 0;

    // const float scale = 1.0f;

    /* Center the message and scale it up */
    // SDL_GetRenderOutputSize(renderer, &w, &h);
    // SDL_SetRenderScale(renderer, scale, scale);

    SDL_Rect clip_rect = {0, 0, 640, 480};
    SDL_SetRenderClipRect(renderer, &clip_rect);

    /* Draw the message */
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);



    app_set_cwd(system_app);
    app_update(system_app);

    SDL_RenderPresent(renderer);

    struct App *app;
    kh_foreach_value(apps, app, {
        if (app->queue_destroy == true) {
            app_destroy(app);
        }
    });

    return SDL_APP_CONTINUE;
}

/* This function runs once at shutdown. */
void SDL_AppQuit(void *appstate, SDL_AppResult result)
{
    printf("quitting..");
}
