(var v (require "v"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))

(fn _has [e ks]
  (var res true)
  (each [_ n (ipairs ks)]
    (set res (and res (if (= (. e n) nil) false true)))) 
  (if res true false))

(fn system [ks f]
  (fn [es]
    (each [_ e (ipairs es)]
      (if (_has e ks) (f e)))))

(var sprites 
  (system [:sprite :pos] 
    (fn [e]
      (let [wpos (view.world->screen _G.window e.pos)
            spr-pos (v.vmul e.sprite 16 16)]
        (draw_sprite "entities.png"
                  wpos.x wpos.y spr-pos.x spr-pos.y 16 16)))))

(var gravities 
  (system [:gravity :velocity] 
    (fn [e]
      (set e.velocity (v.vadd e.velocity (v.v2 0 (* _G.dt 7)))) )))

(var velocities 
  (system [:velocity :pos] 
    (fn [e]
      (set e.last-pos (util.copy e.pos))
      (let [maxspeed (or e.maxspeed 2)
            x (math.min (math.max e.velocity.x (- maxspeed)) maxspeed)
            y (math.min (math.max e.velocity.y (- 4)) 5)]
        (set e.velocity (v.v2 x y))
        (set e.pos (v.vadd e.pos e.velocity))) )))

(var physics 
  (system [:velocity :bounds :solid] 
    (fn [e]
      ;floor
      (let [res (or (grid.point-in-solid-tile (v.vadd e.pos (v.v2 (- e.bounds.br.x 1) e.bounds.br.y)))
                (grid.point-in-solid-tile (v.vadd e.pos (v.v2 (+ e.bounds.ul.x 1) e.bounds.br.y))))]

      (when res
        (set e.touching-floor 0.12)
        (if (. res 2)
          (do (set e.pos.y (- e.pos.y (. res 2)))
              (set e.velocity.y (- (* (. res 2) 0.5))))
          (do (set e.pos.y e.last-pos.y)
              (set e.velocity.y (* e.velocity.y -.1))))))

      ;ceiling
      (when (or (grid.point-in-solid-tile (v.vadd e.pos (v.v2 (- e.bounds.br.x 1) e.bounds.ul.y)))
                (grid.point-in-solid-tile (v.vadd e.pos (v.v2 (+ e.bounds.ul.x 1) e.bounds.ul.y))))
        (set e.pos.y e.last-pos.y)
        (set e.velocity.y (* e.velocity.y -.1))
        (set e.jumping false))

      ;walls
      ;TODO probably need to get collision offset because one can still get stuck 
      (let [res (or (grid.point-in-solid-tile (v.vadd e.pos (v.v2 e.bounds.ul.x (- e.bounds.br.y 2))))
                (grid.point-in-solid-tile (v.vadd e.pos (v.v2 e.bounds.br.x (- e.bounds.br.y 2))))

                (grid.point-in-solid-tile (v.vadd e.pos (v.v2 e.bounds.ul.x (+ e.bounds.ul.y 1))))
                (grid.point-in-solid-tile (v.vadd e.pos (v.v2 e.bounds.br.x (+ e.bounds.ul.y 1)))))]
        (when res
          (if (. res 2)
              (do (set e.pos.y (- e.pos.y (. res 2)))
                  (set e.touching-floor 0.12))
              (do (set e.pos.x e.last-pos.x)
                  (set e.velocity.x (* e.velocity.x -.2))
                  (set e.touching-wall 0.1)))))

      (when e.touching-floor
        (set e.touching-wall false)
        (set e.velocity.x (* e.velocity.x 0.8))
        (set e.touching-floor (- e.touching-floor _G.dt))
        (if (< e.touching-floor 0)
          (set e.touching-floor false))) 

      (when e.touching-wall
        (if (> e.velocity.y 0) (set e.velocity.y (* e.velocity.y 0.95)))
        (set e.touching-wall (- e.touching-wall _G.dt))
        (if (< e.touching-wall 0)
          (set e.touching-wall false))))))

; record jump button time
; when on ground if time within threshold start :jumping
; while jump button down within time span add to velocity

(var controls 
  (system [:velocity :pos] 
    (fn [e]
      (let [speed (if e.touching-floor (* 18 _G.dt) (* 8 _G.dt))]
        (if (key_down "left") (set e.velocity.x (+ e.velocity.x (- speed))))
        (if (key_down "right") (set e.velocity.x (+ e.velocity.x speed)))
        (if (key_pressed "space")
          (set e.jump_pressed_at _G.time))
        (when (and 
                (not e.jumping)
                e.touching-floor 
                e.jump_pressed_at 
                (< (- _G.time e.jump_pressed_at) 0.1))
          (set e.jumping true)
          (set e.velocity.y (* -60 _G.dt)))
        (if e.jumping
          (if (< (- _G.time e.jump_pressed_at) 0.15)
            (if (key_down "space")
              (set e.velocity.y (+ e.velocity.y (* -19 _G.dt)))
              (set e.jumping false))
            (set e.jumping false)))
        ))))

(var types {
  :player {
    :pos (v.v2 2048 2008)
    :velocity (v.v2 0 0)
    :gravity true
    :sprite (v.v2 0 0)
    :solid true
    :bounds {:ul (v.v2 3 2) :br (v.v2 11 16)}
  }})

(fn new [k] (util.copy (. types k)))

{ :new new
  :sprites sprites
  :gravities gravities
  :velocities velocities
  :physics physics
  :controls controls}