
(var v (require "v"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))

(fn prn [x] (print (fennel.view x)))

;TODO
; [ ] key input binding
; [ ] arrow key navigation for map editor
; [ ] decoration map layer


(var time 0)

(var tile 0)



(set _G.state (or _G.state (util.read-bin "state.data") {
  :world (grid.make 256 256 -1)}))
(local state _G.state)

(var window (view.new 10 20 388 388))

(set window.camera (v.v2 250 200))

(fn save-state []
  (util.write-bin "state.data" state))

(load_img "sprites.png")
(load_img "world_sprites.png")

(fn button [x y w h label f]
  (let [(mx my) (mouse_pos)
        over? (v.v_in_rect (v.v2 mx my) (v.v2 x y) (v.v2 (+ x w) (+ y h)))
        color (if over? true false)]
    (draw_rect x y w h color)
    (draw_rect_lines x y w h 1 (not color))
    (draw_text label (+ x (/ w 2) (* (/ (# label) 2) -6)) (+ y (/ h 2) 3) (not color))
    (when (and over? (mouse_pressed 1)) (f))))

(fn handle-draw [] 
  (let [(mx my) (mouse_pos)
        tloc (view.screen->tile window (v.v2 mx my))
        sloc (view.tile->screen window tloc)]   
    (when (and (v.v_in_rect (v.v2 mx my) window.tl window.br)
               (grid.in-bounds state.world tloc))
      (draw_rect_lines (- sloc.x 2) (- sloc.y 2) 20 20 2 false)
      (when (mouse_down 1)
        (grid.gset state.world tloc tile))
      (when (mouse_down 0)
        (grid.gset state.world tloc -1)))))

(fn draw-tiles []
  (let [(mx my) (mouse_pos)]
    (for [x 0 7]
      (for [y 0 7]
        (let [idx (+ x (* y 8))
              sv (v.vmul (v.v2 x y) 16) ;sprite coords
              p (v.vadd (v.vmul (v.v2 x y) 22) (v.v2 420 20))
              outline (fn [] (draw_rect_lines (- p.x 2) (- p.y 2) 22 22 1 true))]
          (draw_rect_lines p.x p.y 18 18 1 true)
          (draw_sprite "world_sprites.png"
            (+ p.x 1) (+ p.y 1) sv.x sv.y 16 16)

          (when (= idx tile)
            (outline))

          (when (v.v_in_rect (v.v2 mx my) p (v.vadd p (v.v2 16 16)))
            (outline)
            (when (mouse_pressed 1) (set tile idx)
              (prn tile))
            ))))))

(fn update [dt]
  (set time (+ time dt))
  (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 580 8 true)

  

  (draw-tiles)
  (view.draw window state)
  (handle-draw)

  (button 420 200 172 30 "save map" (fn [] (prn "saved map") (save-state))))

{:update update}