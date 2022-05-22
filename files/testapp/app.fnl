(print "app says hello ")

(var time 0)

(load_img "./files/testapp/sprites.png")

(fn update [dt]
  (set time (+ time dt))
  (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 2 8 true)
  (for [x 1 20] 
    (for [y 2 12]  
      (if 
        (or (= x 1) (= x 20) (= y 2) (= y 12)) 
        (draw_sprite "./files/testapp/sprites.png"
          (* x 8) (* y 8) 0 0 8 8)

        (= (% (* y x) 6) 0)
        (draw_sprite "./files/testapp/sprites.png"
          (* x 8) (* y 8) 8 8 8 8))))

  (draw_text 
    "(Hello Pixel Perfect World!)" 16 116
     true)

  (draw_sprite "./files/testapp/sprites.png"
    (+ 64 (* (math.sin time) 20)) 
    (+ 54 (* (math.cos time) 20)) 8 0 8 8)
  )

{:update update}