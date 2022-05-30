(var globals (require "globals"))
(var v (require "v"))
(var ui (require "ui"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))

(fn prn [x] (print (fennel.view x)))

(var state _G.state)

(var tile 0)

(var layer :world)

(var window (view.new 10 20 380 448))
(set _G.editor_window window)

(set window.camera-target (v.v2 250 200))

(fn save-state []
  (util.write-bin "state.data" state))




(fn handle-draw [] 
  (let [target (if (= layer :world) state.world
                   (= layer :background) state.background)
        (mx my) (mouse_pos)
        tloc (view.screen->tile window (v.v2 mx my))
        sloc (view.tile->screen window tloc)]   
    (when (and (v.v_in_rect (v.v2 mx my) window.tl window.br)
               (grid.in-bounds target tloc))
      (draw_text (fennel.view tloc) 10 15 true)
      (draw_rect_lines (- sloc.x 2) (- sloc.y 2) 20 20 2 false)
      (when (mouse_down 1)
        (grid.gset target tloc tile))
      (when (mouse_down 0)
        (grid.gset target tloc -1)))))

(fn draw-tiles []
  (let [(mx my) (mouse_pos)]
    (for [x 0 7]
      (for [y 0 7]
        (let [idx (+ x (* y 8))
              sv (v.vmul (v.v2 x y) 16) ;sprite coords
              p (v.vadd (v.vmul (v.v2 x y) 22) (v.v2 420 20))
              outline (fn [] (draw_rect_lines (- p.x 2) (- p.y 2) 22 22 1 true))]
          (draw_rect p.x p.y 18 18 true)
          (draw_sprite (if (= layer :world) "world_sprites.png" 
                           (= layer :background) "background_sprites.png") 
            (+ p.x 1) (+ p.y 1) sv.x sv.y 16 16)

          (when (= idx tile)
            (outline))

          (when (v.v_in_rect (v.v2 mx my) p (v.vadd p (v.v2 16 16)))
            (outline)
            (when (mouse_pressed 1) (set tile idx)
              (prn tile))))))))

(fn update [dt]

  (let [pan (v.v2 (if (key_down "left") -1  (key_down "right") 1 0)
                  (if (key_down "up") -1  (key_down "down") 1 0))
        pan (v.vmul pan 10 dt)]
    (set window.camera-target (v.vadd window.camera-target pan)))

  (set window.camera (util.vlerp window.camera window.camera-target 0.1))
  
  (draw-tiles)
  (view.draw window state)
  (handle-draw)
  (draw_text (.. "editing " layer " layer") 454 204 true)
  (ui.button 420 210 80 16 "world" (fn [] (set layer :world)))
  (ui.button 510 210 82 16 "background" (fn [] (set layer :background)))
  (ui.button 420 240 172 30 "save map" (fn [] (save-state)))
  (ui.button 420 280 172 30 "back to menu" (fn [] (set _G.mode :menu) )))

{:update update}