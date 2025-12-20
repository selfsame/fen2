
; standard lib stuff

(fn identity [x] x)

(fn inc [n] (+ n 1))

(fn dec [n] (- n 1))

(fn nil? [x] (= x nil))

(fn true? [x] (if x true false))

(fn empty? [x] (= 0 (# x)))

(fn first [col] (. col 1))

(fn last [col] (. col (# col)))

(fn rest [col]
  (let [a []]
    (if (< (# col) 2) a
      (do (for [i 2 (# col)]
        (tset a (dec i) (. col i))) a))))

(fn map [f col]
  (let [a []]
    (each [i v (pairs col)]
      (tset a i (f v))) a))

(fn reduce [f val col]
  (if (empty? col) val
    (reduce f (f val (first col)) (rest col))))

(fn add [m v] (table.insert m v))

(fn filter [f col]
  (let [a []]
    (each [i v (pairs col)]
      (if (f v) (add a v))) a))

(fn every? [f col]
  (reduce (fn [a b] (and (f a) (f b))) (first col) (rest col)))

(fn int [n] (math.floor n))

(fn copy [o]
  (if (= (type o) "table")
    (let [t {}]
      (each [k v (pairs o)]
        (tset t k (copy v))) t) o))

(fn merge [a b]
  (let [c (copy a)]
    (each [k v (pairs b)]
      (tset c k (copy v))) c))

(fn update [col k f] (tset col k (f (. col k))) col)

(fn keys [col]
  (let [res []]
    (each [k v (pairs col)] (add res k)) res))

(fn has-key? [m k] (not (= nil (. m k))))

(fn vals [col]
  (let [res []]
    (each [k v (pairs col)] (add res v)) res))

(fn get [col k nf]
  (or (. col k) nf))

;remove first matching value, is this what pico8 has?
(fn remove [col o]
  (var found false)
  (each [i v (ipairs col)]
    (if (= v o)
      (when (not found)
        (set found true)
        (table.remove col i)))) col)


(fn tableprint [o]
  (if
    (= (type o) "function")
    "<fn>"
    (= (type o) "table")
    (do
      (var res "{")
      (each [k v (pairs o)]
        (set res (.. res k ": " (tableprint v) ", ")))
      (set res (.. res "}")) res)
    (= o true) "true"
    (= o false) "false"
    (= o nil) "nil"
    (.. o)))


; game stuff

(fn chance [n] (<= (math.random 100) n))

(fn rand [n] (math.random n))

(fn rand-nth [col] (. col (rand (# col))))

{:identity identity
 :inc inc
 :dec dec
 :nil? nil?
 :true? true?
 :empty? empty?
 :first first
 :last last
 :rest rest
 :map map
 :reduce reduce
 :add add
 :filter filter
 :every? every?
 :int int
 :copy copy
 :merge merge
 :update update
 :keys keys
 :has-key? has-key?
 :vals vals
 :get get
 :remove remove
 :tableprint tableprint
 :chance chance
 :rand rand
 :rand-nth rand-nth}
