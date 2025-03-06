(var v (require "v"))
(var util (require "util"))



; generation

(fn drunk-dungeon [m point cnt tile bav]
  (var lastdrunk (v.v2 1 0))
  (var point point)
  (for [i 1 cnt]
    (util.gset m point tile)
    (let [dir (if (util.chance (or bav 50)) lastdrunk
                  (util.rand-nth [(v.v2 -1 0) (v.v2 1 0) (v.v2 0 -1) (v.v2 0 1)]))
          nv (v.vadd point dir)]
      (set lastdrunk dir)
      (when (util.in-border m nv)
        (set point nv))
      ))
  )

(fn bsp [x y w h depth]
  (if (> depth 0)
      (let [split (if (> (math.random) 0.5) :h :v)
            split-pos (if (= split :h)
                          (+ y (math.random (math.max 1 (- h 8))))
                          (+ x (math.random (math.max 1 (- w 8)))))]
        (if (= split :h)
            (let [room1 (bsp x y w split-pos (- depth 1))
                  room2 (bsp x (+ split-pos 1) w (- h split-pos 1) (- depth 1))]
              (print (.. "Hallway: " x "," (+ split-pos 1) " to " x "," split-pos))
              (values room1 room2))
            (let [room1 (bsp x y split-pos h (- depth 1))
                  room2 (bsp (+ split-pos 1) y (- w split-pos 1) h (- depth 1))]
              (print (.. "Hallway: " (+ split-pos 1) "," y " to " split-pos "," y))
              (values room1 room2))))
      (do (print (.. "Room: " x "," y " " w "x" h))
          (values x y w h))))

;(bsp 0 0 64 64 4)

(fn random-tile [m n]
  (let [w (# (. m 1))
        h (# m)
        point (v.v2 (util.rand w) (util.rand h))]
    (if (= (util.gget m point) n) point (random-tile m n))))

(fn make-level [w h depth]
  (var grid (util.gridmap 28 28 0))
  (drunk-dungeon grid (v.v2 14 14) 100 1 80)
  (drunk-dungeon grid (v.v2 14 14) 100 1 70)
  (for [i 0 20]
    (let [point (random-tile grid 1)]
      (drunk-dungeon grid point 10 1 50)))
  {:grid grid})

{:make-level make-level}
