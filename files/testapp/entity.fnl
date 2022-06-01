(var v (require "v"))
(var util (require "util"))
(var grid (require "grid"))
(var view (require "view"))
(var bucket (require "deps/bucket"))

;per technomancy
;(fn has? [tbl x] (accumulate [h? false _ y (ipairs tbl) :until h?] (= x y)))
(fn _has [e ks]
  (var res true)
  (each [_ n (ipairs ks)]
    (set res (and res (if (= (. e n) nil) false true)))) 
  (if res true false))

(fn system [ks f]
  (fn [es]
    (each [_ e (ipairs es)]
      (if (_has e ks) (f e)))))

; only need to do this once for static guys
(var stores
  (system [:pos]
    (fn [e]
      (bucket.bstore _G.view_bucket e)
      (bucket.bstore _G.collision_bucket e))))

(var sprites 
  (system [:sprite :pos] 
    (fn [e]
      (let [wpos (view.world->screen _G.window e.pos)
            sprite (or (if e.dead e.dead_sprite) e.sprite)
            spr-pos (v.vmul sprite 16 16)]
        (if (and e.invincible (> e.invincible 0))
          (if (< (math.cos (* _G.time 70)) 0.3)
            (draw_sprite "entities.png"
                    wpos.x wpos.y spr-pos.x spr-pos.y 16 16))
          (draw_sprite "entities.png"
                    wpos.x wpos.y spr-pos.x spr-pos.y 16 16))))))

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
            y (if e.gravity (math.min (math.max e.velocity.y (- 4)) 5)
                            (math.min (math.max e.velocity.y (- maxspeed)) maxspeed))]
        (set e.velocity (v.v2 x y))
        (set e.pos (v.vadd e.pos e.velocity)))
      (bucket.bstore _G.view_bucket e)
      (bucket.bstore _G.collision_bucket e))))

(fn vertical-collisions [e]
  ;floor
  (let [floor   (or (grid.point-solid-offset (v.vadd e.pos (v.v2 (- e.bounds.br.x 1) e.bounds.br.y)) e.velocity)
                    (grid.point-solid-offset (v.vadd e.pos (v.v2 (+ e.bounds.ul.x 1) e.bounds.br.y)) e.velocity))
        ceiling (or (grid.point-solid-offset (v.vadd e.pos (v.v2 (- e.bounds.br.x 1) e.bounds.ul.y)) e.velocity)
                    (grid.point-solid-offset (v.vadd e.pos (v.v2 (+ e.bounds.ul.x 1) e.bounds.ul.y)) e.velocity))]
    (if floor
      (do 
        (set e.touching-floor 0.2)
        (set e.pos.y (+ e.pos.y floor.offset.y))
        (set e.velocity.y (* e.velocity.y -.1)))

      ceiling
      (do 
        (set e.pos.y (- e.pos.y ceiling.offset.y))
        (set e.velocity.y (* e.velocity.y -.1))
        (set e.jumping false)))
    (or floor ceiling)))

(fn horizontal-collisions [e]
  (let [left (or (grid.point-solid-offset (v.vadd e.pos (v.v2 (- e.bounds.ul.x 1) (- e.bounds.br.y 2))) e.velocity)
                 (grid.point-solid-offset (v.vadd e.pos (v.v2 (- e.bounds.ul.x 1) (+ e.bounds.ul.y 2))) e.velocity))

        right (or (grid.point-solid-offset (v.vadd e.pos (v.v2 (+ e.bounds.br.x 1) (+ e.bounds.ul.y 2))) e.velocity)
                  (grid.point-solid-offset (v.vadd e.pos (v.v2 (+ e.bounds.br.x 1) (- e.bounds.br.y 2))) e.velocity))
        any (or left right)]
    (if 
      left
      (set e.pos.x (+ e.pos.x left.offset.x))
      right
      (set e.pos.x (+ e.pos.x right.offset.x)))
    (when any
      (if any.slope
        (do 
          (set e.touching-floor 0.2)
          (set e.pos.y (+ e.pos.y any.offset.y))
          (set e.velocity.y (+ e.velocity.y (* any.offset.y 1))))
        (do 
          (set e.velocity.x (* e.velocity.x -.2))
          (set e.touching-wall 0.1))))
    any))

(var physics 
  (system [:velocity :bounds :solid] 
    (fn [e]

      (if (> (math.abs e.velocity.x) (math.abs e.velocity.y))
        (or (horizontal-collisions e)
            (vertical-collisions e))
        (or (vertical-collisions e)
            (horizontal-collisions e)))

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
      (when (not e.dead)
        (let [speed (if e.touching-floor (* 18 _G.dt) (* 8 _G.dt))]
          (if (key_down "left") (set e.velocity.x (+ e.velocity.x (- speed))))
          (if (key_down "right") (set e.velocity.x (+ e.velocity.x speed)))
          (when (> _G.jumps 0)
            (if (key_pressed "space")
              (set e.jump_pressed_at _G.time))
            (when (and 
                    (not e.jumping)
                    e.touching-floor 
                    e.jump_pressed_at 
                    (< (- _G.time e.jump_pressed_at) 0.12))
              (set e.jumping true)
              (set e.velocity.y (* -60 _G.dt))
              (set _G.jumps (- _G.jumps 1))              
              (when (= 0 _G.jumps)
                (view.notification [
                      (util.rand-nth ["You've run out of jumps.." "That was your last jump.." "Out of jumps.."]) 
                      "press 'r' when you're ready"]))))
          (if e.jumping
            (if (< (- _G.time e.jump_pressed_at) 0.15)
              (if (key_down "space")
                (set e.velocity.y (+ e.velocity.y (* -19 _G.dt)))
                (set e.jumping false))
              (set e.jumping false))) )))))

; honestly i think just deleting it from the stores is enough
(fn delete-entity [e]
  (bucket.bdel _G.view_bucket e)
  (bucket.bdel _G.collision_bucket e))

; player centric at the moment
(var collisions 
  (system [:bounds] 
    (fn [e]

      (set e.invincible (- e.invincible _G.dt))
      (when (not e.dead)
        (let [near (bucket.bget _G.collision_bucket e.pos)]
          (each [i o (pairs near)]
            (when (and (not (= o e)) o.bounds)
              (when (v.overlap 
                      (v.vadd e.pos e.bounds.ul)
                      (v.vadd e.pos e.bounds.br)
                      (v.vadd o.pos o.bounds.ul)
                      (v.vadd o.pos o.bounds.br))
                (when (and o.hurt (<= e.invincible 0))
                  (set _G.health (- _G.health o.hurt))
                  (set e.invincible 1)
                  (when (<= _G.health 0)
                    (set e.dead true)
                    (view.notification [
                      (util.rand-nth ["looks like you've died" "an unfortunate end" "a fatal mistake" "you've died" "you've perished"]) 
                      "press 'r' to reset"])))
                (when o.pickup 
                  (when (= o.type :jump-bag)
                    (set _G.jumps (+ _G.jumps 1))
                    (set _G.max_jumps (+ _G.max_jumps 1)))
                  (when (= o.type :star)
                    (set _G.stars (+ _G.stars 1)))
                  (when (= o.type :heart)
                    (set _G.health (+ _G.health 1))
                    (set _G.max_health (+ _G.max_health 1)))
                  (delete-entity o)) ))))))))

(var ais 
  (system [:ai] 
    (fn [e]
      (when (= e.ai :wander)
        (set e.velocity.x (+ e.velocity.x (* (math.random -3 3) _G.dt)))
        (set e.velocity.y (+ e.velocity.y (* (math.random -3 3) _G.dt)))
        )
        
      )))


(var types {
  :player {
    :pos (v.v2 2048 2008)
    :velocity (v.v2 0 0)
    :gravity true
    :sprite (v.v2 0 0)
    :dead_sprite (v.v2 0 1)
    :solid true
    :bounds {:ul (v.v2 4 3) :br (v.v2 10 16)}
    :invincible 0}
  :jump-bag {
    :pos (v.v2 0 0)
    :sprite (v.v2 2 0)
    :bounds {:ul (v.v2 0 0) :br (v.v2 16 16)}
    :pickup true}
  :star {
    :pos (v.v2 0 0)
    :sprite (v.v2 3 0)
    :bounds {:ul (v.v2 0 0) :br (v.v2 16 16)}
    :pickup true}
  :heart {
    :pos (v.v2 0 0)
    :sprite (v.v2 3 1)
    :bounds {:ul (v.v2 0 0) :br (v.v2 16 16)}
    :pickup true}
  :spikes {
    :pos (v.v2 0 0)
    :sprite (v.v2 1 0)
    :bounds {:ul (v.v2 0 8) :br (v.v2 16 16)}
    :hurt 1}
  :bee {
    :pos (v.v2 0 0)
    :sprite (v.v2 6 0)
    :velocity (v.v2 0 0)
    :ai :wander
    :solid true
    :bounds {:ul (v.v2 3 5) :br (v.v2 13 13)}
    :maxspeed 1
    :hurt 1}
  })

(fn new [k] 
  (let [e (util.copy (. types k))]
    (set e.initial-pos e.pos)
    (set e.type k) e))

{ :new new
  :types types

  :stores stores
  :sprites sprites
  :gravities gravities
  :velocities velocities
  :physics physics
  :controls controls
  :collisions collisions
  :ais ais}