; vector stuff

(fn v2 [x y] {:x x :y y})
(fn v2= [a b] (and (= a.x b.x) (= a.y b.y)))

(fn vadd [a b] {:x (+ a.x b.x) :y (+ a.y b.y)})
(fn vsub [a b] {:x (- a.x b.x) :y (- a.y b.y)})
(fn vdiv [a b] {:x (/ a.x b.x) :y (/ a.y b.y)})
(fn vtimes [a b] {:x (* a.x b.x) :y (* a.y b.y)})

(fn vmul [a n] {:x (* a.x n) :y (* a.y n)})
(fn dist [a b] (math.sqrt (+ (^ (- a.x b.x) 2) (^ (- a.y b.y) 2))))
(fn vmag [v] (dist v (v2 0 0)))
(fn vnorm [v] (vmul v (/ 1 (vmag v))))
(fn vfn [v f] (v2 (f v.x) (f v.y)))
(fn vint [v] (vfn v math.floor))
(fn vlimit [v n] (if (> (vmag v) n) (vmul (vnorm v) n) v))

(fn v_in_rect [v va vb]
  (and (< va.x v.x vb.x)
       (< va.y v.y vb.y)))

{:v2 v2
:v2= v2=
:vadd vadd
:vsub vsub
:vdiv vdiv
:vtimes vtimes
:vmul vmul
:dist dist
:vmag vmag
:vnorm vnorm
:vfn vfn
:vint vint
:vlimit vlimit
:v_in_rect v_in_rect}