
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
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "keys.h"

KHASH_MAP_INIT_STR(texture_cache, SDL_Texture*)

char *base_path = NULL;

static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

static struct App *system_app = NULL;

/* pointer to the app that is evaluating code */
static struct App *current_app = NULL;


int CUID = 0;
int uid(){
    CUID += 1;
    return CUID;
}

struct App {
    int id;
    char root[PATH_MAX];
    lua_State *lua;
    bool is_system;
    khash_t(texture_cache) *textures;
};

static int _quit(lua_State *L){
    //this causes a segfault
    lua_close(L);
    return 0;
}

static int _load_img(lua_State *L){

    const char *img_path = lua_tostring(L, 1);

    // https://examples.libsdl.org/SDL3/renderer/06-textures/
    char *full_path = NULL;
    SDL_Surface *surface = NULL;
    static SDL_Texture *texture = NULL;

    SDL_asprintf(&full_path, "%s%s", current_app->root, img_path);  /* allocate a string of the full file path */
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

    SDL_DestroySurface(surface);  /* done with this, the texture has a copy of the pixels now. */


    return 0;
}

static int _draw_text(lua_State *L){
    const char *message = lua_tostring(L, 1);
    const int x = lua_tointeger(L, 2);
    const int y = lua_tointeger(L, 3);
    const bool color = lua_tointeger(L, 4);

    // x = ((w / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE * SDL_strlen(message)) / 2;
    // y = ((h / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE) / 2;
    SDL_RenderDebugText(renderer, x, y, message);
    return 0;
}

void app_set_cwd(struct App app){
    if (chdir(app.root) != 0) {
        printf("Failed to change to app directory: %s\n", app.root);
    }
}

void app_eval(struct App app, char *s){
    current_app = &app;
    app_set_cwd(app);
    if (luaL_loadstring(app.lua, s) == LUA_OK) {
        if (lua_pcall(app.lua, 0, 0, 0) != LUA_OK) {
            // Handle error
            printf("Lua error: %s\n", lua_tostring(app.lua, -1));
        }
    } else {
        // Handle loading error
        printf("Lua loading error: %s\n", lua_tostring(app.lua, -1));
    }
}

struct App new_app(char path[], bool is_system){
    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_openlibs(L);             // Open standard libraries

    lua_register(L, "quit", _quit);
    lua_register(L, "load_img", _load_img);
    lua_register(L, "draw_text", _draw_text);

    struct App app = {
        .id = uid(),
        .lua = L,  // Store the pointer
        .is_system = is_system
    };

    app.textures = kh_init(texture_cache);

    char app_path[PATH_MAX];
    snprintf(app_path, sizeof(app_path), "%sfiles%c%s", base_path, PATH_SEP, path);

    strncpy(app.root, app_path, PATH_MAX - 1);
    printf("app.root: %s\n", app.root);

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



void Fen2Init(){
    base_path = SDL_GetBasePath();
    printf("Base path: %s\n", base_path);

    system_app = malloc(sizeof(struct App));
    *system_app = new_app("hello-world", true);
    printf("App id: %d, path: %s\n", system_app->id, system_app->root);
    app_eval(*system_app, "print('ok ok ok!')");
    //app_eval(*system_app, "quit()");
    //app_eval(x, "print('ok ok ok2!')");
}

/* This function runs once at startup. */
SDL_AppResult SDL_AppInit(void **appstate, int argc, char *argv[])
{
    /* Create the window */
    if (!SDL_CreateWindowAndRenderer("Hello World!", 800, 600, SDL_WINDOW_FULLSCREEN, &window, &renderer)) {
        SDL_Log("Couldn't create window and renderer: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    Fen2Init();

    return SDL_APP_CONTINUE;
}

/* This function runs when a new event (mouse input, keypresses, etc) occurs. */
SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event)
{
    if (event->type == SDL_EVENT_KEY_DOWN ||
        event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS;  /* end the program, reporting success to the OS. */
    }
    return SDL_APP_CONTINUE;
}

/* This function runs once per frame, and is the heart of the program. */
SDL_AppResult SDL_AppIterate(void *appstate)
{

    int w = 0, h = 0;

    const float scale = 4.0f;

    /* Center the message and scale it up */
    SDL_GetRenderOutputSize(renderer, &w, &h);
    SDL_SetRenderScale(renderer, scale, scale);


    /* Draw the message */
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);

    app_set_cwd(*system_app);
    app_eval(*system_app, "if app.update then app.update() end");

    SDL_RenderPresent(renderer);

    return SDL_APP_CONTINUE;
}

/* This function runs once at shutdown. */
void SDL_AppQuit(void *appstate, SDL_AppResult result)
{
    printf("quitting..");
}
