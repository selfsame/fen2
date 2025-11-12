(load_img  "default_icon32.png")

(fn update [dt]
  ;(print "updating..")
  (draw_text "hello world"  10 10 true)
  (draw_img  "default_icon32.png" 10 40)
  (draw_sprite  "default_icon32.png" 40 40 5 5 10 10)
  (set_pixel 2 2 false)
  (draw_rect 10 100 60 40 false)
  (draw_rect_lines 80 100 60 40 false)
  (for [x 1 400]
    (for [y 1 100]
      (if (= 1 (math.fmod (math.fmod x y) 2))
        (set_pixel (+ x 10) (+ y 200) false))))
  )

(print "hello-world")

{:update update}
