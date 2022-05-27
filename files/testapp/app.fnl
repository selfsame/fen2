(var u (require "util"))
(var grid (require "grid"))


(print "app says hello ")

(var time 0)

(var tile 0)

(var world (grid.make 40 40 -1))

(load_img "sprites.png")
(load_img "world_sprites.png")

(fn sprite-idx->v2 [idx size]
  (v2 (% idx size)
      (math.floor (/ idx size))))

(fn draw-world []
  (for [x 1 24]
    (for [y 1 24]
      (let [tile (grid.gget world (v2 x y))
            tpos (vmul (sprite-idx->v2 tile 8) 16)
            v (vadd (vmul (v2 x y) 16) (v2 -4 6))]
        (draw_sprite "world_sprites.png"
            v.x v.y tpos.x tpos.y 16 16) ))))

(fn handle-draw [] 
  (let [(mx my) (mouse_pos)
        loc (vsub (v2 mx my) (v2 10 20))
        tloc (vadd (vfn (vmul loc (/ 1 16)) math.floor) (v2 1 1))
        rloc (vadd (vmul (vsub tloc (v2 1 1)) 16) (v2 10 20))]
    (when (v_in_rect (v2 mx my) (v2 10 20) (v2 388 388))
      (draw_rect_lines rloc.x rloc.y 21 21 2 false)
      (if (mouse_down 1)
        (grid.gset world tloc tile)))))

(fn draw-tiles []
  (let [(mx my) (mouse_pos)]
    (for [x 0 7]
      (for [y 0 7]
        (let [idx (+ x (* y 8))
              sv (vmul (v2 x y) 16) ;sprite coords
              v (vadd (vmul (v2 x y) 22) (v2 420 20))
              outline (fn [] (draw_rect_lines (- v.x 2) (- v.y 2) 22 22 1 true))]
          (draw_rect_lines v.x v.y 18 18 1 true)
          (draw_sprite "world_sprites.png"
            (+ v.x 1) (+ v.y 1) sv.x sv.y 16 16)

          (when (= idx tile)
            (outline))

          (when (v_in_rect (v2 mx my) v (vadd v (v2 16 16)))
            (outline)
            (when (mouse_pressed 1) (set tile idx)
              (prn tile))
            ))))))

(fn update [dt]
  (set time (+ time dt))
  (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 580 8 true)

  (draw_rect 10 20 388 388 true)

  (draw-tiles)
  (draw-world)
  (handle-draw))


{:update update}