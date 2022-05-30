(var v (require "v"))
(var grid (require "grid"))


; a map drawing module
(print "view.fnl")


(fn new [x y w h]
  (let [tl (v.v2 x y)
        wh (v.v2 w h)
        br (v.vadd tl wh)
        tile-wh (v.vint (v.vdiv wh (v.v2 16 16)))]
  {:tl tl
   :wh wh
   :br br
   :tile-wh tile-wh
   :camera (v.v2 0 0)
   :camera-target (v.v2 0 0)}))

(fn screen->tile [view pos]
  (grid.p->t 
    (v.vsub 
      (v.vsub (v.vadd pos view.camera) view.tl)
      (v.vmul view.wh 0.5))))

(fn world->screen [view pos]
  (v.vadd 
    (v.vadd (v.vsub pos view.camera) view.tl)
    (v.vmul view.wh 0.5)))

(fn tile->screen [view tpos]
  (world->screen view (grid.t->p tpos)))



(fn sprite-idx->v2 [idx size]
  (v.v2 (% idx size)
      (math.floor (/ idx size))))


(fn draw [view state]
  (let [cam-tpos (grid.p->t view.camera)
        t-ul (v.vint (v.vsub cam-tpos (v.vmul view.tile-wh 0.5)))
        t-br (v.vadd (v.vadd t-ul view.tile-wh) (v.v2 1 1))]
    (draw_rect view.tl.x view.tl.y view.wh.x view.wh.y true)
    
    (for [x t-ul.x t-br.x]
      (for [y t-ul.y t-br.y]
        (let [tile (grid.gget _G.state.world (v.v2 x y))
              bgtile (grid.gget _G.state.background (v.v2 x y))
              tile (if (and tile (<= 0 tile)) tile nil)
              bgtile (if (and bgtile (<= 0 bgtile)) bgtile nil)]
          (when (or tile bgtile)

            (let [spr-pos (v.vmul (sprite-idx->v2 (or tile bgtile) 8) 16)
                  tpos (tile->screen view (v.v2 x y))]
              (when bgtile 
                (draw_sprite "background_sprites.png"
                  tpos.x tpos.y spr-pos.x spr-pos.y 16 16))
              (when tile
                (draw_sprite "world_sprites.png"
                  tpos.x tpos.y spr-pos.x spr-pos.y 16 16))

                   )))))

    ; clip our map view with white rects
    (draw_rect  0  0 view.tl.x (+ view.tl.y view.wh.y 16) false)
    (draw_rect  0  0 (+ view.tl.x view.wh.x 16) view.tl.y  false)
    (draw_rect  (+ view.tl.x view.wh.x)  0 18 (+ view.tl.y view.wh.y 16)  false)
    (draw_rect  0  (+ view.tl.y view.wh.y) (+ view.tl.x view.wh.x 16) (+ view.tl.y view.wh.y 16)  false) ))



{ :new new :draw draw :screen->tile screen->tile :tile->screen tile->screen
  :world->screen world->screen }