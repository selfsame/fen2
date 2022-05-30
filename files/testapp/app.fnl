(var globals (require "globals"))
(var v (require "v"))
(var ui (require "ui"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))
(var editor (require "editor"))
(var entity (require "entity"))

(fn prn [x] (print (fennel.view x)))

;TODO
; [x] decoration map layer
; [ ] tile collision returns offset
; [x] camera dead zone
; [ ] pickup entities
; [ ] place entities in map editor
; [ ] jump pickups
; [ ] star pickups
; [ ] key to reset game
; [ ] level layout
; [ ] win condition


; [ ] sounds
; [ ] fx entities
; [ ] bucket hash lib on entities


(var state _G.state)

(set _G.time 0)


(var tile 0)

(load_img "world_sprites.png")
(load_img "background_sprites.png")
(load_img "entities.png")




(var window (view.new 20 20 600 440))

(var player (entity.new :player))
(set window.camera player.pos)
(set window.camera-target player.pos)
(var guys [player])

(fn restart [] 
  (set player.pos (. (entity.new :player) :pos))
  (set player.velocity (v.v2 0 0)))

(fn update [dt]
  (set _G.time (+ _G.time dt))
  (set _G.dt dt)
  (if (key_pressed "escape") (set _G.mode :menu))
  (if (key_pressed "r") (restart))
  (if (= _G.mode :editor) (editor.update dt))
  (when (= _G.mode :game)
    (set _G.window window)
    (view.draw window state)
    (entity.controls [player])
    (entity.sprites guys)
    (entity.gravities guys)
    (entity.velocities guys)
    (entity.physics guys)

    (if player.touching-floor
      (draw_text "FLOOR" 20 470 true))
    (if player.touching-wall
      (draw_text "WALL" 100 470 true))

    ; camera should stay within X distance of player
    (let [cam-dist (v.dist window.camera-target player.pos)]
      (if (> cam-dist 50)
        (let [to-player (v.vmul (v.vnorm (v.vsub player.pos window.camera-target)) (- cam-dist 50))]
          (set window.camera-target (v.vadd window.camera-target to-player)))))
    
    (set window.camera (util.vlerp window.camera window.camera-target 0.1)))
  (when (= _G.mode :menu)
    (ui.button 220 160 200 30 "start game" (fn [] (set _G.mode :game)))
    (ui.button 220 200 200 30 "map editor" 
      (fn [] 
        (set _G.editor_window.camera (util.copy player.pos))
        (set _G.editor_window.camera-target (util.copy player.pos))
        (set _G.mode :editor))))
  (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 580 8 true))


{:update update}