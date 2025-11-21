(var foo (require "foo"))

(load_img  "default_icon32.png")

(print "hello-world loaded")

(var dir (list_files "../"))

(var timer 0)

(fn update [dt]
  (set timer (+ timer dt))
  (draw_img  "default_icon32.png" (+ 320 (* (math.cos (* timer 2)) 320)) 400)
  ;(print "updating..")
  (draw_text "hello world"  10 10)
  (draw_text foo.text  10 30)
  (let [(x y) (mouse_pos)]
    (draw_text (.. (math.floor x) " " (math.floor y)) 120 10))
  (draw_text timer 200 10 )
  (draw_img  "default_icon32.png" 10 40)
  (draw_sprite  "default_icon32.png" 40 40 5 5 10 10)
  (draw_sprite  "default_icon32.png" 80 40 5 5 10 10)
  (set_pixel 2 2 false)
  (draw_rect 10 100 60 40 false)
  (draw_rect_lines 80 100 60 40 false)
  (for [x 1 400]
    (for [y 1 100]
      (if (= 1 (math.fmod (math.fmod x y) 11))
        (set_pixel (+ x 10) (+ y 200) false))))

  (var y 310)
  (each [k v (pairs dir)]
    (draw_text k 10 y true)
    (set y (+ y 12)))
)

{:update update}
