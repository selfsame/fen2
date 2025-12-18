(load_img  "patterns.png")
(load_img  "window.png")
(load_img  "default_icon32.png")

(var running-apps {})
(var app-idx 0)

(fn _find-apps [dir found]
  (let [files (list_files dir)]
    (if (. files "app.fnl")
      (if (not (= dir "../system/"))
        (table.insert found dir))
      (each [k v (pairs files)]
          (if (= v "dir")
            (_find-apps (.. dir k "/") found))))))

(fn find-apps [dir]
  (let [found []]
    (_find-apps dir found)
    (table.sort found)
    found))

(fn draw-window [x y w h f]
  (draw_9patch "window.png" 4 4 15 4 x y w h)
  (draw_img "patterns.png" (+ x w -15) (+ y 1) 0 40 13 13)
  ;(draw_img "patterns.png" (+ x w -15) (+ y 1) 16 40 13 13)
  (clip_rect (+ x 3) (+ y 15) (- w 7) (- h 19))
  (f)
  (clip_rect))


(fn start []
  (print "system starting.."))

(fn count [col]
  (var cnt 0)
  (each [k v (pairs col)]
    (set cnt (+ cnt 1)))
  cnt)

(fn index-of-key [col key]
  (var cnt 0)
  (var res nil)
  (each [k v (pairs col)]
    (set cnt (+ cnt 1))
    (if (= k key)
      (set res cnt)))
  res)

(fn handle_quit [pid]
  (print "handle_quit" pid)
  (tset running-apps pid nil)
  (set app-idx 0)
  (close_process pid))

(fn update [dt]
  (when (key_pressed "tab")
    (set app-idx (+ app-idx 1))
    (if (> app-idx (count running-apps))
      (set app-idx 0)))
  (when (= app-idx 0)
    (clear_screen false)
    (draw_text "FEN2" 280 90 true)
    (draw_text (.. (count running-apps) " running apps") 2 10 true)
    (draw_text "[tab] to cycle app, [q] to quit current app" 186 10 true)

    (draw_img "patterns.png" 0 14 32 0 8 8 640 466 true)
    (draw_rect 0 14 640 1 true)



    (let [app_paths (find-apps "../")]
      (each [i path (ipairs app_paths)]
        (let [files (list_files path)
              x 200
              y (+ (* 50 i) 100)
              (mx my) (mouse_pos)
              mouse-over? (and (< x mx (+ x 200)) (< (- y 16) my (+ y 16)))
              ]
          (draw_rect (- x 2) (- y 18) 204 36 mouse-over?)
          (draw_rect_lines (- x 4) (- y 20) 208 40 1 (not mouse-over?))
          (if (. files "icon32.png")
            (do
              (load_img (.. path "icon32.png"))
              (draw_img (.. path "icon32.png") x (- y 16) 0 0 32 32))
            (draw_img "default_icon32.png" x (- y 16) 0 0 32 32))
          (draw_text path  (+ x 40) (+ y 4) (not mouse-over?))
          (if (and mouse-over? (mouse_pressed 1))
            (let [new-app (launch_process path)]

              (tset running-apps new-app true)
              (set app-idx (index-of-key running-apps new-app))))))))
    (var i 0)
    (each [app _ (pairs running-apps)]
      (set i (+ i 1))
      (when (= i app-idx)
        ; (if (key_pressed "m")
        ;   (send_message app "hello child"))
        (if (key_pressed "q")
          (handle_quit app)
          (do
            (update_process app dt)
            (target_rendertexture 0)
            (draw-window 340 50 280 200 (fn []
              (draw_app_rendertexture app 0 343 64)
              )


               ))))

     )

    (when false
      (draw_rect 590 0 640 13 false)
      (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 592 11 true))
    )



{:start start
 :update update
 :handle_quit handle_quit}
