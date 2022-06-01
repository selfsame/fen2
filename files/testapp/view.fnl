(var v (require "v"))
(var util (require "util"))
(var grid (require "grid"))
(var bucket (require "deps/bucket"))

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

(set _G.notifications [])

(fn notification [s duration]
  (let [note {:message s :y -60}]
    (util.tween note :y 0 0.8 {:e (util.powf 2) :f 
      (fn [_] (util.wait (or duration 4) 
        (fn [_] (util.tween note :y -60 0.8 {:e (util.powf 2) :f (fn [_] (util.del _G.notifications note))}))))})
    (table.insert _G.notifications note)))

(fn draw [view state]
  (util.update-tweens)
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
                  tpos.x tpos.y spr-pos.x spr-pos.y 16 16)) )))))))

(fn draw-notifications [window]
  (each [i note (ipairs _G.notifications)]
    (let [_top (+ window.tl.y 6 note.y)
          midpoint (v.v2 (+ window.tl.x (* window.wh.x 0.5)) (math.max 0 _top))
          width 300
          height (if (< _top 0) (+ 60 _top) 60)
          mheight (* (# note.message) 12)]

      (draw_rect (- midpoint.x (* width 0.5)) midpoint.y width height true)
      (draw_rect_lines (- midpoint.x (* width 0.5)) midpoint.y width height  1 false)
      (draw_rect_lines (+ (- midpoint.x (* width 0.5)) 3) (+ midpoint.y 3) (- width 6) (- height 6)  2 false)
      (each [i line (ipairs note.message)]
        (draw_text line (- midpoint.x (* (# line) 5.3 0.5)) 
          (+ midpoint.y -2 (* height 0.5) (- (* mheight 0.5)) (* i 12)) false)))))

(fn mask-view [view]
  ; clip our map view with white rects
  (draw_rect  0  0 view.tl.x (+ view.tl.y view.wh.y 16) false)
  (draw_rect  0  0 (+ view.tl.x view.wh.x 100) view.tl.y  false)
  (draw_rect  (+ view.tl.x view.wh.x)  0 300 (+ view.tl.y view.wh.y 16)  false)
  (draw_rect  0  (+ view.tl.y view.wh.y) (+ view.tl.x view.wh.x 16) (+ view.tl.y view.wh.y 16)  false))

{ :new new :draw draw :screen->tile screen->tile :tile->screen tile->screen
  :world->screen world->screen :mask-view mask-view
  :notification notification :draw-notifications draw-notifications}