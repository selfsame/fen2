(var v (require "v"))
(var util (require "util"))

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

(var slopes {
  12 [0 16]
  13 [1 7]
  14 [8 16]

  20 [16 8]
  21 [7 0]
  22 [16 0]})

; truthy if this point is inside a "solid"
(fn point-in-solid-tile [p]
  (let [tpos (p->t p)
        found (gget _G.state.world tpos)]
    (when (and found (> found -1))
      (let [slope (. slopes found)]
        (if slope 
          (let [offset (v.vsub p (t->p tpos))
                height (util.lerp (. slope 1) (. slope 2) (/ offset.x 16))]
            (when (> offset.y height)

              [found (- offset.y height)]))
          [found nil])))))

; if p is inside a tile returns [tile offset-vector] where
; the offset is determined by the `vel`
; one one axis of offset is of interest to me
(fn point-solid-offset [p vel]
  (let [tpos (p->t p)
        found (gget _G.state.world tpos)]
    (when (and found (> found -1))
      (let [tile-pos (t->p tpos)
            slope (. slopes found)]
        (if slope ; could maybe ignore some velocity conditions for slope checking
          (let [offset (v.vsub p (t->p tpos))
                height (util.lerp (. slope 1) (. slope 2) (/ offset.x 16))]
            (when (> offset.y height)

              {:tile found :slope true :offset (v.v2 0 (- (- offset.y height)))}))
          (let [ox (if (< vel.x 0) 
                       (- (+ tile-pos.x 16) p.x)
                       (- (- p.x tile-pos.x)))
                oy (if (< vel.y 0) 
                       (- (- (+ tile-pos.y 16) p.y))
                       (- (- p.y tile-pos.y)))
                ; hack to prevent glitching when checking the wrong axis for an intersection
                ox (if (> ox 6) 0
                       (< ox -6) 0 ox)
                oy (if (> oy 6) 0
                       (< oy -6) 0 oy)]
            {:tile found :offset (v.v2 ox oy)} ))))))

{:make make :in-bounds in-bounds :gget gget :gset gset
 :p->t p->t
 :t->p t->p
 :point-in-solid-tile point-in-solid-tile
 :point-solid-offset point-solid-offset}