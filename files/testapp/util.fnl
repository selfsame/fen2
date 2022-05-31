(var binser (require "deps/binser"))
(var v (require "v"))

(fn write-data [path data]
  (match (io.open path "w")
    f (do (f:write (fennel.view data)) (f:close))
    (nil err-msg) (print "Could not open file:" err-msg)))

(fn read-data [path]
  (match (io.open path)
    f (let [res (fennel.eval (f:read :*all))]
          (f:close)
          res)
    (nil err-msg) nil))

(fn write-bin [path data] (binser.writeFile path data))

(fn read-bin [path] 
  (match (io.open path)
    f (do (f:close) (let [[res _] (binser.readFile path)] res))
    (nil err-msg) nil))

(fn copy [o]
  (if (= (type o) "table")
    (let [t {}]
      (each [k v (pairs o)]
        (tset t k (copy v))) t)
    o))

(var _ts {})

(fn lerp [a b r] (+ a (* (- b a) r)))
(fn vlerp [a b r] (v.vadd a (v.vmul (v.vsub b a) r)))
(fn powf [n] (fn [v] (^ v n)))

(fn tween [o p v d _]
  (let [_ (or _ {})
        t {:o o :p p :v v :d d :s d
           :f _.f
           :l (or _.l lerp)
           :ei (or _.ei _.e)
           :eo (or _.eo _.e)
           :iv (or (and p (. o p)) o)}]
    (table.insert _ts t) t))

(fn wait [d f] (tween 0 nil 0 d {:f f}))

(fn update-tweens []
  (local ts {})
  (each [_ t (ipairs _ts)]
    (when t.o
      (set t.d (- t.d 1))
      (var r (- 1 (/ t.d t.s)))
      (if (and t.ei t.eo)
          (set r (or (and (< r 0.5) (/ (t.ei (* r 2)) 2))
                     (- 1 (/ (t.eo (* (- 1 r) 2)) 2))))
          t.ei
          (set r (t.ei r))
          t.eo
          (set r (- 1 (t.eo (- 1 r)))))
      (var z (t.l t.iv t.v r))
      (if t.p (tset t.o t.p z)
              (set t.o z))
      (if (> t.d 0) (table.insert ts t)
          (if t.f (t.f t.o)))))
  (set _ts ts))

;(tween object prop_name target_value duration options_table)
; options are 
; :e dual in+out easing fn
; :ei,:eo in,out easing fn
; :f tween callback (takes 1 argument - the object)
; :l lerping function

(fn add [m v] (table.insert m v))

(fn filter [f col]
  (let [a []]
    (each [i v (pairs col)]
      (if (f v) (add a v))) a))

{ :write-data write-data
  :read-data read-data
  :write-bin write-bin
  :read-bin read-bin
  :copy copy
  :lerp lerp
  :vlerp vlerp
  :tween tween
  :wait wait
  :update-tweens update-tweens
  :add add
  :filter filter}