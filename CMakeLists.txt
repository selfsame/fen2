cmake_minimum_required(VERSION 3.16)
project(fen2)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -fsanitize=address -fno-omit-frame-pointer -O1")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# set the output directory for built objects.
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/")

# This assumes the SDL source is available in vendored/SDL
add_subdirectory(vendored/SDL EXCLUDE_FROM_ALL)

# Use pre-built LuaJIT library
add_library(lua STATIC IMPORTED)
set_target_properties(lua PROPERTIES
    IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/vendored/luajit/src/libluajit.a
)
target_include_directories(lua INTERFACE ${CMAKE_SOURCE_DIR}/vendored/luajit/src)

# Create your game executable target as usual
add_executable(fen2 WIN32
    src/main.c
    src/keys.c
)

# Link to SDL3 and Lua, etc..
target_link_libraries(fen2 PRIVATE SDL3::SDL3 lua m)
target_include_directories(fen2 PRIVATE vendored/luajit/src)
target_include_directories(fen2 PRIVATE vendored/klib)
target_include_directories(fen2 PRIVATE vendored/dmon)
target_link_libraries(fen2 PRIVATE pthread)

# Copy files directory to build
file(COPY fennel.lua reloader.fnl DESTINATION ${CMAKE_BINARY_DIR})
