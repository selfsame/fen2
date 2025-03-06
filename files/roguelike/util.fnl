(var v (require "v"))

(fn gridmap [w h fill]
  (let [res []]
    (for [y 1 h]
      (let [row []]
        (for [x 1 w]
          (tset row x fill))
        (tset res y row)))
    res))

(fn in-bounds [m v]
  (if (<= 1 v.y (# m))
    (if (<= 1 v.x (# (. m 1))) true false)
    false))

(fn in-border [m v]
  (if (<= 2 v.y (- (# m) 1))
    (if (<= 2 v.x (- (# (. m 1)) 1)) true false)
    false))

(fn gget [m v]
  (if (in-bounds m v)
    (. (. m (. v :y)) (. v :x))))

(fn gset [m v x]
  (if (in-bounds m v)
    (tset (. m (. v :y)) (. v :x) x)))

(fn in-bounds [m v]
  (if (<= 1 v.y (# m))
    (if (<= 1 v.x (# (. m 1))) true false)
    false))

(fn in-border [m v]
  (if (<= 2 v.y (- (# m) 1))
    (if (<= 2 v.x (- (# (. m 1)) 1)) true false)
    false))

(fn rand [n] (math.random n))

(fn rand-nth [col] (. col (rand (# col))))

(fn chance [n] (<= (math.random 100) n))

{:gridmap gridmap
 :in-bounds in-bounds
 :in-border in-border
 :gget gget
 :gset gset
 :in-bounds in-bounds
 :in-border in-border
 :rand rand
 :rand-nth rand-nth
 :chance chance}
