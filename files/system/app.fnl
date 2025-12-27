(var util (require "util"))

(load_img  "patterns.png")
(load_img  "window.png")
(load_img  "default_icon32.png")

(var running-apps [])
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

(fn count [col]
  (var cnt 0)
  (each [k v (pairs col)]
    (set cnt (+ cnt 1)))
  cnt)

(fn parse-val [s]
  (let [n (tonumber s)]
    (if n n
      (if (= "false" s) false
        (if (= "true" s) true
          s)))))

; TODO parse IDENTIFIER boolean | number | string
(fn parse-config [path]
  (let [config {}]
    (match (io.open (.. path "config"))
      f (let [res (f:read :*all)]
          (f:close)
          (print "CONFIG")
          (each [line (string.gmatch res "[^\r\n]+")]
            (let [col []]
              (each [word (string.gmatch line "%S+")]
                (table.insert col (parse-val word)))
              (if (= (# col) 2)
                (tset config (. col 1) (. col 2))
                (tset config (. col 1) (util.rest col)))))
          (print (fennel.view res)))
      (nil err-msg) nil)
    config))

(fn handle_quit [pid]
  (print "handle_quit" pid)
  (set running-apps (util.filter (fn [window] (not= window.id pid)) running-apps))
  (close_process pid))

(var window-z 0)

(fn new-window [id path]
  (let [name (or (string.match path "([^/]+)/$") "??")]
    (set window-z (+ window-z 1))
    {:x (math.random 30 100) :y (math.random 40 100) :w 200 :h 100 :id id :title name :idx window-z}))

(fn draw-window [{: x : y : w : h : title : close-button} f]
  (draw_9patch "window.png" 4 4 15 4 x y w h)
  (let [tlen (* (# title) 6)
        tx (+ x (/ w 2) (* tlen -0.5))]
    (clip_rect (+ x 1) (+ y 1) (+ w -16) 14)
    (draw_rect tx (+ y 1) tlen 13 false)
    (draw_text title (+ tx 4) (+ y 12) true)
    (clip_rect))
  (if close-button
    (draw_img "patterns.png" (+ x w -15) (+ y 1) 16 40 13 13)
    (draw_img "patterns.png" (+ x w -15) (+ y 1) 0 40 13 13))
  (clip_rect (+ x 3) (+ y 15) (- w 7) (- h 19))
  (f)
  (clip_rect))


(fn start []
  (print "system starting.."))

(fn sorted-apps []
  (table.sort running-apps (fn [a b] (< a.idx b.idx)))
  running-apps)

(fn index-of-key [col key]
  (var cnt 0)
  (var res nil)
  (each [k v (pairs col)]
    (set cnt (+ cnt 1))
    (if (= k key)
      (set res cnt)))
  res)

(fn mouse-over? [x y w h]
  (let [(mx my) (mouse_pos)]
    (and (< x mx (+ x w)) (< y my (+ y h)))))

(var mouse-move-fn nil)
(var mouse-up-fn nil)

(fn handle-mouse-down []
  (when (mouse_pressed 1)
    (let [(x y) (mouse_pos)
          window (util.last (util.filter (fn [window]
                   (and (< window.x x (+ window.x window.w))
                        (< window.y y (+ window.y window.h)))) (sorted-apps)))]

      (when window
        (set window-z (+ window-z 1))
        (tset window :idx window-z)
        (if (mouse-over? (+ window.x window.w -14) window.y 14 14)
          (do (tset window :close-button true)
              (set mouse-up-fn (fn []
                (if (mouse-over? (+ window.x window.w -14) window.y 14 14)
                  (handle_quit window.id)
                  (tset window :close-button false)))))
          (let [over-bar? (mouse-over? window.x window.y window.w 14)
                over-resizer? (and (not= window.resizable false) (mouse-over? (+ window.x window.w -6) (+ window.y window.h -6) 6 6))]
          (if (or over-bar? over-resizer?)
            (let [(startx starty) (mouse_pos)]
              (var lastx startx)
              (var lasty starty)
              (set mouse-move-fn (fn []
                (let [(mx my) (mouse_pos)
                      dx (- mx lastx)
                      dy (- my lasty)]
                  (set lastx mx)
                  (set lasty my)
                  (when over-bar?
                    (tset window :x (util.round (+ window.x dx)))
                    (tset window :y (util.round (+ window.y dy))))
                  (when over-resizer?
                    (tset window :w (util.round (+ window.w dx)))
                    (tset window :h (util.round (+ window.h dy))))
                )))))))))))

(fn check-input []
  (when (mouse_pressed 1)
    (handle-mouse-down))
  (when (mouse_down 1)
    (if mouse-move-fn (mouse-move-fn)))
  (when (mouse_released 1)
    (if mouse-up-fn (mouse-up-fn))
    (set mouse-move-fn nil)
    (set mouse-up-fn nil)))



(fn update [dt]

  (when true ;(= app-idx 0)
    (clear_screen false)
    (draw_text "FEN2" 280 90 true)
    (draw_text (.. (# running-apps) " running apps") 2 10 true)
    (draw_text (fennel.view (mouse_down 1)) 160 10 true)

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
            (let [config (parse-config path)
                  app-id (launch_process path)
                  window (new-window app-id path)]
              (print (fennel.view config))
              (when config.WINDOW
                (tset window :w (. config.WINDOW 1))
                (tset window :h (. config.WINDOW 2)))
              (when config.RESIZABLE
                (tset window :resizable config.RESIZEABLE))
              (table.insert running-apps window) ))))))

    (check-input)
    (each [i window (pairs (sorted-apps))]
      (when (= i (# running-apps))
        (set_mouse_offset (+ window.x 3) (+ window.y 15) )
        (update_process window.id dt))
      (draw-window window (fn []
        (draw_app_rendertexture window.id 0 (+ window.x 3) (+ window.y 14))) ))
    (set_mouse_offset 0 0)
    (when true
      (draw_rect 590 0 640 13 false)
      (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 592 11 true)))



{:start start
 :update update
 :handle_quit handle_quit}
