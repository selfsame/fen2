(fn _G.prn [x] (print (fennel.view x)))

; vector stuff

(fn _G.v2 [x y] {:x x :y y})
(fn _G.v2= [a b] (and (= a.x b.x) (= a.y b.y)))

(fn _G.vadd [a b] {:x (+ a.x b.x) :y (+ a.y b.y)})
(fn _G.vsub [a b] {:x (- a.x b.x) :y (- a.y b.y)})
(fn _G.vdiv [a b] {:x (/ a.x b.x) :y (/ a.y b.y)})
(fn _G.vtimes [a b] {:x (* a.x b.x) :y (* a.y b.y)})

(fn _G.vmul [a n] {:x (* a.x n) :y (* a.y n)})
(fn _G.dist [a b] (math.sqrt (+ (^ (- a.x b.x) 2) (^ (- a.y b.y) 2))))
(fn _G.vmag [v] (_G.dist v (v2 0 0)))
(fn _G.vnorm [v] (_G.vmul v (/ 1 (_G.vmag v))))
(fn _G.vfn [v f] (_G.v2 (f v.x) (f v.y)))

(fn _G.v_in_rect [v v1 v2]
  (and (< v1.x v.x v2.x)
       (< v1.y v.y v2.y)))

