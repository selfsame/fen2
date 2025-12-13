(load_img  "../jumpminster/world_sprites.png")

(fn update [dt]
  (.. "asdfkj" "asdf " "asd asdf  ")
  (for [x 0 40]
    (for [y 0 30]
      (draw_img "../jumpminster/world_sprites.png" (* x 16) (* y 16)
        (* (math.random 8) 16) (* (math.random 5) 16) 16 16)
      )))

{:update update}
