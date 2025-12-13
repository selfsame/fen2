(var foo (require "foo"))

(load_img  "default_icon32.png")
(load_img  "window.png")

(print "hello-world loaded")

(var dir (list_files "../"))

(var timer 0)

(var rtex (create_rendertexture 512 512))

(print "render texture created:" rtex)

(local ffi (require "ffi"))
(local C ffi.C)

(ffi.cdef "
  int printf(const char *fmt, ...);
  void __set_pixel(int x, int y, int c);
  ")

(C.printf "Hello from C!\n")
(print (ffi.load "cairo"))
(print (ffi.load "m"))
;(print C.__set_pixel)




(fn update [dt]
  (clear_screen true)

  (target_rendertexture rtex)
  (clear_screen true)
  (set timer (+ timer dt))
  (draw_img "default_icon32.png" (+ 320 (* (math.cos (* timer 2)) 320)) 400)
  ;(print "updating..")
  (draw_text "hello world"  10 10)
  (draw_text (.. foo.text (foo.frog 2))  10 30)
  (let [(x y) (mouse_pos)]
    (draw_text (.. (math.floor x) " " (math.floor y)) 120 10))
  (draw_text timer 200 10 )
  (draw_img "default_icon32.png" 10 40)
  (draw_img "default_icon32.png" 40 40 5 5 10 10)
  (draw_img "default_icon32.png" 80 40 5 5 10 10)
  (set_pixel 2 2 false)
  (target_rendertexture 0)

  (draw_rect 200 100 60 40 false)
  (draw_rect_lines 280 100 60 40 false)
  (for [x 1 400]
    (for [y 1 100]
      (if (= 1 (math.fmod (math.fmod x y) 11))
        (set_pixel (+ x 10) (+ y 200) false))))

  (var y 310)
  (each [k v (pairs dir)]
    (draw_text k 10 y true)
    (set y (+ y 12)))


  (fn draw-window [x y w h f]
    (draw_9patch "window.png" 3 3 11 3 x y w h)
    (clip_rect (+ x 3) (+ y 11) (- w 6) (- h 14))
    (f)
    (clip_rect))

  (draw-window 10 10 300 100
    (fn [] (draw_rendertexture rtex 13 21)))
  (draw-window 120 60 300 100
    (fn [] (draw_rendertexture rtex 123 71 nil nil nil nil 1024 1024))) )

{:update update}
