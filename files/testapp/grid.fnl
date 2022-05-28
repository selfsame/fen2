(var v (require "v"))

(fn make [w h fill]
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

(fn p->t [p]
  (v.vadd (v.vfn (v.vmul p (/ 1 16)) math.floor) (v.v2 1 1)))

(fn t->p [t]
  (v.vmul (v.vsub t (v.v2 1 1)) 16))

{:make make :in-bounds in-bounds :gget gget :gset gset
 :p->t p->t
 :t->p t->p}