(var globals (require "globals"))
(var v (require "v"))
(var ui (require "ui"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))
(var editor (require "editor"))
(var entity (require "entity"))
(var bucket (require "deps/bucket"))


(set _G.prn (fn prn [x] (print (fennel.view x))))
(var prn _G.prn)


;TODO
; [x] hurt collisions
; [x] hurt animation
; [x] jump pickups
; [x] star pickups
; [x] dead state
; [x] in game notifications (drop down message rect)
; [ ] win condition (just a notification)
; [ ] content
; [ ] simple title screen 
; [ ] fix multiple jump used bug


; [ ] sounds
; [ ] fx entities



(var state _G.state)

(set _G.time 0)

(var tile 0)

(load_img "title.png")
(load_img "world_sprites.png")
(load_img "background_sprites.png")
(load_img "entities.png")


(var window (view.new 170 20 450 440))

(var player (entity.new :player))
(set window.camera player.pos)
(set window.camera-target player.pos)
(var guys [])

(fn new-game []
  (set player (entity.new :player))
  (set guys (util.map (fn [e] (let [e (util.copy e)] (set e.initial-pos e.pos) e)) state.entities))
  (set _G.guys guys)
  (table.insert guys player)
  (set _G.view_bucket {:size 600 :prop "pos"})
  (set _G.collision_bucket {:size 16 :prop "pos"})
  (entity.stores guys)

  (set _G.max_jumps 0)
  (set _G.jumps 0)
  (set _G.max_health 1)
  (set _G.health 1)

  (set _G.stars 0)
  (set _G.max_stars (# (util.filter (fn [e] (= e.type :star)) guys))))

(fn restart [] 
  ;TODO should swap player in guys for fresh table?
  (set _G.notifications [])
  (bucket.bdel _G.view_bucket player)
  (bucket.bdel _G.collision_bucket player)
  (set player (entity.new :player))
  (entity.stores [player])
  (set _G.guys (util.filter (fn [e] (not (= e.type :player))) guys))
  (table.insert _G.guys player)
  (each [i guy (ipairs _G.guys)]
    (set guy.pos guy.initial-pos))

  (set _G.jumps _G.max_jumps)
  (set _G.health _G.max_health))

(new-game)

;(set state.entities (util.map (fn [e] (set e.initial-pos nil)) state.entities))
;(prn state.entities)

(fn open-editor []
  (set _G.mouse_bad 20)
  (set _G.editor_window.camera (util.copy player.pos))
  (set _G.editor_window.camera-target (util.copy player.pos))
  (set _G.mode :editor))

(fn update [dt]
  (set _G.time (+ _G.time dt))
  (set _G.dt dt)
  (if (key_pressed "escape") (set _G.mode :menu))
  (if (key_pressed "e") (open-editor))
  (when (key_pressed "r") (set _G.mode :game) (restart))
  (when (key_pressed "n") (set _G.mode :game) (new-game))
  (when (= _G.mode :editor)
    (editor.update dt))
  (when (= _G.mode :game)
    (set _G.window window)
    (view.draw window state)
    (let [viewable (bucket.bget _G.view_bucket window.camera)]
      (entity.controls [player])
      (entity.collisions [player])
      (entity.sprites viewable)
      (entity.gravities viewable)
      (entity.velocities viewable)
      (entity.physics viewable)
      (entity.ais viewable))
    (view.draw-notifications window)
    (view.mask-view window state) 


    (draw_text "JUMPMINSTER" 170 8 true)

    (if player.touching-floor
      (draw_text "FLOOR" 170 470 true))
    (if player.touching-wall
      (draw_text "WALL" 210 470 true))

    (draw_text "HEARTS" 20 27 true)
    (ui.icon-bar _G.health _G.max_health 20 37 11 (v.v2 0 3))

    (draw_text "STARS " 20 80 true)
    (ui.icon-bar _G.stars _G.max_stars 20 90 11 (v.v2 0 4))

    (draw_text "JUMPS"  20 140 true)
    (ui.icon-bar _G.jumps _G.max_jumps 20 150 11 (v.v2 0 5))
    
    (draw_text "SPACE TO JUMP"  20 300 true)
    (draw_text "ARROWS TO MOVE"  20 320 true)
    (draw_text "R TO RESET"  20 340 true)

    (draw_text "FIND JUMP BAGS"  20 420 true)
    (draw_text "FIND HEARTS"  20 440 true)
    (draw_text "FIND THE STARS"  20 460 true)

    ; camera should stay within X distance of player
    (let [cam-dist (v.dist window.camera-target player.pos)]
      (if (> cam-dist 50)
        (let [to-player (v.vmul (v.vnorm (v.vsub player.pos window.camera-target)) (- cam-dist 50))]
          (set window.camera-target (v.vadd window.camera-target to-player)))))
    (set window.camera (util.vlerp window.camera window.camera-target 0.1)))

  (when (= _G.mode :menu)
    (draw_rect 0 0 640 480 true)
    (draw_img "title.png" 100 80)
    (ui.button 220 280 200 30 "enter game" (fn [] (set _G.mode :game)))
    (ui.button 220 320 200 30 "new game" (fn [] (new-game) (set _G.mode :game)))
    (ui.button 220 360 200 30 "map editor" open-editor))
  (draw_text (.. "FPS: " (math.floor (/ 1 dt))) 580 8 true))


{:update update}