#include <time.h>
#include "SDL3/SDL_log.h"
#include "SDL3/SDL_pixels.h"
#define DMON_IMPL
#include "dmon.h"
#include "SDL3/SDL_render.h"
#include "SDL3/SDL_timer.h"
#include <linux/limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <khash.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#define STB_TRUETYPE_IMPLEMENTATION
#include <stb_truetype.h>
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
//#include "luajit.h"
#include <lauxlib.h>
#include "keys.h"

#define APP_BASE_WIDTH 640
#define APP_BASE_HEIGHT 480

bool fullscreen = false;

float mousex = 0;
float mousey = 0;

float mouse_offset_x = 0;
float mouse_offset_y = 0;

KHASH_MAP_INIT_STR(texture_cache, SDL_Texture*)
KHASH_MAP_INIT_INT(rendertexture_cache, SDL_Texture*)
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
    int rt_id;
    khash_t(rendertexture_cache) *rendertextures;
    bool queue_destroy;
};

static void set_bw_color(bool c){
    if (c) {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    } else {
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    }
}

/* Font Stuff */

typedef struct {
    float font_size;
    SDL_Texture* texture;
    stbtt_bakedchar chars[700];
} Font;

static Font *default_font = NULL;

Font* load_font(const char* path, float font_size){
    size_t ttf_size;
    unsigned char* ttf_buffer = (unsigned char*)SDL_LoadFile(path, &ttf_size);
    if (!ttf_buffer) {
    SDL_Log("Failed to load font %s: %s", path, SDL_GetError());
        SDL_free(ttf_buffer);
        return NULL;
    }

    Font* font = malloc(sizeof(Font));

    int atlas_w = round(font_size*10);
    int atlas_h = round(font_size*10);
    /* think here i have to use stb lib to find the range of glyphs, it will crash if out of range */
    int code_range = 250;
    unsigned char atlas[atlas_w*atlas_h];

    int result = stbtt_BakeFontBitmap(ttf_buffer, 0, font_size,
        atlas, atlas_w, atlas_h, 0, code_range, font->chars);

    /* unfortunately there's no SDL 8 bit texture format?  */
    unsigned char* rgba_atlas = malloc(atlas_w * atlas_h * 4);
    for (int i = 0; i < atlas_w * atlas_h; i++) {
        /* Here I hack the alpha to avoid aliased pixels */
        rgba_atlas[i*4 + 0] = atlas[i] > 100 ? 255 : 0 ; // A
        rgba_atlas[i*4 + 1] = 255;      // R
        rgba_atlas[i*4 + 2] = 255;        // G
        rgba_atlas[i*4 + 3] = 255;        // B
    }

    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB32,
                                                 SDL_TEXTUREACCESS_STATIC,
                                                 atlas_w, atlas_h);
    SDL_UpdateTexture(texture, NULL, rgba_atlas, atlas_w * 4);
    SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
    SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST);

    SDL_free(ttf_buffer);


    font->texture = texture;
    font->font_size = font_size;
    return font;
}

/* stbtt_bakedchar has the sub rect of the glyph along with xadvance which
 * i think is just the width. I can do a simple text render from that with no
 * kerning. Also noting I may want to use stbtt_GetBakedQuad which looks to have
 */
void draw_font_text(Font *font, float x, float y, char* text){
    SDL_FRect src, dest;
    for (const char* p = text; *p; p++) {
        char c = *p;
        if (c < 0 || c > 700) continue; // ok goof, unsigned chars are 0-255
        stbtt_aligned_quad q;
        stbtt_GetBakedQuad(font->chars, 512, 512, c, &x, &y, &q, 1);
        src = (SDL_FRect){q.s0 * 512, q.t0 * 512, (q.s1 - q.s0) * 512, (q.t1 - q.t0) * 512};
        dest = (SDL_FRect){q.x0, q.y0, q.x1 - q.x0, q.y1 - q.y0};
        SDL_RenderTexture(renderer, font->texture, &src, &dest);
    }
}

int app_create_rendertexture(struct App *app, int w, int h){
    SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB32, SDL_TEXTUREACCESS_TARGET, w, h);
    SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_NEAREST);
    int ret;
    khint_t k = kh_put(rendertexture_cache, app->rendertextures, app->rt_id, &ret);
    kh_value(app->rendertextures, k) = texture;
    app->rt_id += 1;
    return app->rt_id - 1;
}

SDL_Texture* app_get_rendertexture(struct App *app, int k){
    khint_t ck = kh_get(rendertexture_cache, app->rendertextures, k);
    if (ck != kh_end(app->rendertextures)) {
        return kh_value(app->rendertextures, ck);
    } else {
        return NULL;
    }
}

bool app_destroy_rendertexture(struct App *app, int k){
    SDL_Texture *texture = app_get_rendertexture(app, k);
    if (texture == NULL) return 0;
    SDL_DestroyTexture(texture);
    kh_del(rendertexture_cache, app->rendertextures, k);
    return 1;
}

bool app_set_rendertexture(struct App *app, int k){
    SDL_Texture *texture = app_get_rendertexture(app, k);
    if (texture == NULL) return 0;
    SDL_SetRenderTarget(renderer, texture);
    return 1;
}

void app_set_cwd(struct App *app){
    if (chdir(app->root) != 0) {
        printf("Failed to change to app directory: %s\n", app->root);
    }
}

/* as the only entrypoint to lua we set some app specific state, then reset after the eval.
 * this allows things like nested app evals where the state is always restored */
void app_eval(struct App *app, char *s){
    struct App *prev_app = current_app;
    SDL_Texture *prev_render_target = SDL_GetRenderTarget(renderer);
    current_app = app;
    app_set_cwd(app);
    app_set_rendertexture(app, 0);
    if (luaL_loadstring(app->lua, s) == LUA_OK) {
        if (lua_pcall(app->lua, 0, 0, 0) != LUA_OK) {
            printf("Lua error: %s\n", lua_tostring(app->lua, -1));
        }
    } else {
        printf("Lua loading error: %s\n", lua_tostring(app->lua, -1));
    }
    lua_gc(app->lua, LUA_GCCOLLECT, NULL);
    current_app = prev_app;
    if (current_app) app_set_cwd(current_app);
    SDL_SetRenderTarget(renderer, prev_render_target);
}

void app_update(struct App *app){
    char buffer[60];
    sprintf(buffer, "if app and app.update then app.update(%f) end", delta);
    app_eval(app, buffer);
}

#include "api.c"



struct App * new_app(char path[], bool is_system){
    struct App *app = malloc(sizeof(struct App));

    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_openlibs(L);             // Open standard libraries

    lua_register(L, "quit", _quit);
    lua_register(L, "list_files", _list_files);
    lua_register(L, "clear_screen", _clear_screen);
    lua_register(L, "clip_rect", _clip_rect);
    lua_register(L, "load_sound", _load_sound);
    lua_register(L, "play_sound", _play_sound);
    lua_register(L, "load_img", _load_img);
    lua_register(L, "draw_img", _draw_img);
    lua_register(L, "draw_9patch", _draw_9patch);
    lua_register(L, "create_rendertexture", _create_rendertexture);
    lua_register(L, "destroy_rendertexture", _destroy_rendertexture);
    lua_register(L, "target_rendertexture", _target_rendertexture);
    lua_register(L, "draw_rendertexture", _draw_rendertexture);
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
        lua_register(L, "set_mouse_offset", _set_mouse_offset);
        lua_register(L, "draw_app_rendertexture", _draw_app_rendertexture);
    }


    app->id = uid();
    app->lua = L;
    app->is_system = is_system;
    app->textures = kh_init(texture_cache);
    app->rt_id = 0;
    app->rendertextures = kh_init(rendertexture_cache);
    app->queue_destroy = false;

    char app_path[PATH_MAX];
    snprintf(app_path, sizeof(app_path), "%sfiles%c%s", base_path, PATH_SEP, path);

    strncpy(app->root, app_path, PATH_MAX - 1);
    printf("app.root: %s\n", app->root);

    app_create_rendertexture(app, APP_BASE_WIDTH, APP_BASE_HEIGHT);

    /* register app in the apps cache by id */
    int ret;
    khint_t k = kh_put(app_cache, apps, app->id, &ret);
    kh_value(apps, k) = app;

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
    for (k = kh_begin(app->rendertextures); k != kh_end(app->rendertextures); ++k) {
        if (kh_exist(app->rendertextures, k)) {
            SDL_Texture *texture = kh_val(app->rendertextures, k);
            SDL_DestroyTexture(texture);
        }
    }
    kh_destroy(texture_cache, app->rendertextures);
    if (app->lua) lua_close(app->lua);
    khint_t app_key = kh_get(app_cache, apps, app->id);
    if (app_key != kh_end(apps)) {
        kh_del(app_cache, apps, app_key);
    }
    free(app);
    if (is_system) exit(0);
}

bool starts_with(const char *a, const char *b){
    if(strncmp(a, b, strlen(b)) == 0) return 1;
    return 0;
}

bool ends_with(const char *str, const char *suffix)
{
    if (!str || !suffix)
        return 0;
    size_t lenstr = strlen(str);
    size_t lensuffix = strlen(suffix);
    if (lensuffix >  lenstr)
        return 0;
    return strncmp(str + lenstr - lensuffix, suffix, lensuffix) == 0;
}

typedef struct {
    struct App *app;
    char code[PATH_MAX * 2];
} ReloadTask;

static ReloadTask reload_queue[100];
static int reload_queue_count = 0;

static void watch_callback(dmon_watch_id watch_id, dmon_action action, const char* rootdir,
                           const char* filepath, const char* oldfilepath, void* user)
{
    if (action != 1 && action != 3) return;

    char full_filepath[PATH_MAX];
    snprintf(full_filepath, sizeof(full_filepath), "%sfiles%c%s", base_path, PATH_SEP, filepath);

    struct App *app;
    kh_foreach_value(apps, app, {
        if (starts_with(full_filepath, app->root)) {
            if (ends_with(full_filepath, ".fnl") || ends_with(full_filepath, ".lua")) {
                char buffer[PATH_MAX];

                const char *relative_path = full_filepath + strlen(app->root);
                if (*relative_path == PATH_SEP) relative_path++;

                /* There is likely an issue with reloading where transitive deps aren't getting the new values */
                sprintf(buffer, "reloader.reload_path('%s'); app = require('app')", relative_path);
                /* have to eval lua code on the main thread (i think) */
                if (reload_queue_count < 10) {
                    reload_queue[reload_queue_count].app = app;
                    strcpy(reload_queue[reload_queue_count].code, buffer);
                    reload_queue_count++;
                }
            }
        }
    });

}

void Fen2Init(){
    default_font = load_font("HelvetiPixel.ttf", 14);
    //default_font = load_font("consola.ttf", 54);

    apps = kh_init(app_cache);
    base_path = SDL_GetBasePath();
    printf("Base path: %s\n", base_path);

    dmon_init();
    dmon_watch_id watcher;
    watcher = dmon_watch("./files", watch_callback, DMON_WATCHFLAGS_RECURSIVE | DMON_WATCHFLAGS_FOLLOW_SYMLINKS, NULL);
    printf("watcher id: %d\n", watcher.id);

    system_app = new_app("system", true);
    printf("App id: %d, path: %s\n", system_app->id, system_app->root);
}

int main(int argc, char *argv[])
{
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        SDL_Log("Couldn't initialize SDL: %s", SDL_GetError());
        return 1;
    }

    /* Create the window */
    if (!SDL_CreateWindowAndRenderer("Fen2", APP_BASE_WIDTH, APP_BASE_HEIGHT, NULL, &window, &renderer)) {
        SDL_Log("Couldn't create window and renderer: %s", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_SetRenderVSync(renderer, 1);

    Fen2Init();
    last_timestamp = SDL_GetPerformanceCounter();

    // Main loop
    int running = 1;
    while (running) {

        SDL_GetMouseState(&mousex, &mousey);
        int windoww, windowh;
        SDL_GetWindowSize(window, &windoww, &windowh);

        if (windoww > APP_BASE_WIDTH * 2 && windowh > APP_BASE_HEIGHT * 2 ) {
            SDL_Rect viewport = {(windoww-(APP_BASE_WIDTH*2))/4, (windowh-APP_BASE_HEIGHT*2)/4,
                                 APP_BASE_WIDTH*2, APP_BASE_HEIGHT*2};
            SDL_SetRenderViewport(renderer, &viewport);
            SDL_SetRenderScale(renderer, 2.0f, 2.0f);
        } else {
            SDL_SetRenderScale(renderer, 1.0f, 1.0f);
            SDL_Rect viewport = {(windoww-APP_BASE_WIDTH)/2, (windowh-APP_BASE_HEIGHT)/2,
                                 APP_BASE_WIDTH, APP_BASE_HEIGHT};
            SDL_SetRenderViewport(renderer, &viewport);
        }
        float renderx, rendery;
        SDL_RenderCoordinatesFromWindow(renderer, mousex, mousey, &renderx, &rendery);
        mousex = renderx;
        mousey = rendery;


        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = 0;
            }
            if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_F11 && !event.key.repeat) {
                fullscreen = !fullscreen;
                SDL_SetWindowFullscreen(window, fullscreen);
            }
        }

        // Update timing
        Uint64 now = SDL_GetPerformanceCounter();
        delta = (double)(now - last_timestamp) / SDL_GetPerformanceFrequency();
        last_timestamp = now;

        update_mouse_states();
        update_key_states();

        // need to clear screen in case window size/fullscreen has changed
        SDL_SetRenderClipRect(renderer, NULL);
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);

        SDL_Rect clip_rect = {0, 0, APP_BASE_WIDTH, APP_BASE_HEIGHT};
        SDL_SetRenderClipRect(renderer, &clip_rect);
        /* Draw the message */
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        // SDL_RenderClear(renderer);
        SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

        /* eval any file reloads from the watcher thread */
        for (int i = 0; i < reload_queue_count; i++) {
            app_eval(reload_queue[i].app, reload_queue[i].code);
        }
        reload_queue_count = 0;

        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);

        app_update(system_app);
        SDL_Texture* system_texture = app_get_rendertexture(system_app, 0);
        SDL_FRect dest = {0, 0, APP_BASE_WIDTH, APP_BASE_HEIGHT};
        SDL_RenderTexture(renderer, system_texture, NULL, &dest);

        clock_gettime(CLOCK_MONOTONIC, &end);
        double millis = (end.tv_sec - start.tv_sec) * 1000.0 + (end.tv_nsec - start.tv_nsec) / 1000000.0;
        // printf("Time: %.3f milliseconds\n", millis);

        // draw_font_text(default_font, 40, 40, "Hello World?");
        // SDL_FRect dest = {50,50,default_font->texture->w, default_font->texture->h};
        // SDL_RenderTexture(renderer, default_font->texture, NULL, &dest);

        SDL_RenderPresent(renderer);

        struct App *app;
        kh_foreach_value(apps, app, {
            if (app->queue_destroy == true) {
                app_destroy(app);
            }
        });
    }

    dmon_deinit();

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
