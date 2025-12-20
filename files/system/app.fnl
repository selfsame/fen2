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

(var window-z 0)

(fn new-window [id name]
  (set window-z (+ window-z 1))
  {:x (math.random 30 100) :y (math.random 40 100) :w 200 :h 100 :id id :title name :idx window-z})

(fn draw-window [{: x : y : w : h : title} f]
  (draw_9patch "window.png" 4 4 15 4 x y w h)
  (let [tlen (* (# title) 6)
        tx (+ x (/ w 2) (* tlen -0.5))]
    (draw_rect tx (+ y 1) tlen 13 false)
    (draw_text title (+ tx 4) (+ y 12) true))
  (draw_img "patterns.png" (+ x w -15) (+ y 1) 0 40 13 13)
  ;(draw_img "patterns.png" (+ x w -15) (+ y 1) 16 40 13 13)
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



(fn check-input []
  (when (mouse_pressed 1)
    (let [(x y) (mouse_pos)
          window (util.last (util.filter (fn [window]
                   (and (< window.x x (+ window.x window.w))
                        (< window.y y (+ window.y window.h)))) (sorted-apps)))]

      (when window
        (set window-z (+ window-z 1))
        (tset window :idx window-z))
      )))

(fn handle_quit [pid]
  (print "handle_quit" pid)
  (set running-apps (util.filter (fn [window] (not= window.id pid)) running-apps))
  (close_process pid))

(fn update [dt]

  (when true ;(= app-idx 0)
    (clear_screen false)
    (draw_text "FEN2" 280 90 true)
    (draw_text (.. (# running-apps) " running apps") 2 10 true)

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
            (let [app-id (launch_process path)]
              (table.insert running-apps (new-window app-id path)) ))))))

    (check-input)

    (var i 0)
    (each [_ window (pairs (sorted-apps))]
      (set i (+ i 1))
      (when true ;(= i app-idx)
        ; (if (key_pressed "m")
        ;   (send_message app "hello child"))
        (if (key_pressed "q")
          (handle_quit window.id)
          (do
            (update_process window.id dt)
            (draw-window window (fn []
              (draw_app_rendertexture window.id 0 (+ window.x 3) (+ window.y 14))) )))))

    (when true
      (draw_rect 590 0 640 13 false)
      (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 592 11 true)))



{:start start
 :update update
 :handle_quit handle_quit}
