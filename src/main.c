
#include <stdio.h>
#define SDL_MAIN_USE_CALLBACKS 1  /* use the callbacks instead of main() */
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "keys.h"

static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

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
};

static int _quit(lua_State *L){
    //this causes a segfault
    lua_close(L);
    return 0;
}

struct App new_app(char path[], bool is_system){
    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_openlibs(L);             // Open standard libraries

    lua_register(L, "quit", _quit);

    struct App app = {
        .id = uid(),
        .lua = L,  // Store the pointer
        .is_system = is_system
    };
    strncpy(app.root, path, PATH_MAX - 1);

    return app;
}

void app_eval(struct App app, char *s){
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

void Fen2Init(){
    struct App x = new_app("system", true);
    printf("App id: %d, path: %s\n", x.id, x.root);
    app_eval(x, "print('ok ok ok!')");
    app_eval(x, "quit()");
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
    const char *message = "Hello World!";
    int w = 0, h = 0;
    float x, y;
    const float scale = 4.0f;

    /* Center the message and scale it up */
    SDL_GetRenderOutputSize(renderer, &w, &h);
    SDL_SetRenderScale(renderer, scale, scale);
    x = ((w / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE * SDL_strlen(message)) / 2;
    y = ((h / scale) - SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE) / 2;

    /* Draw the message */
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderDebugText(renderer, x, y, message);
    SDL_RenderPresent(renderer);

    return SDL_APP_CONTINUE;
}

/* This function runs once at shutdown. */
void SDL_AppQuit(void *appstate, SDL_AppResult result)
{
    printf("quitting..");
}
