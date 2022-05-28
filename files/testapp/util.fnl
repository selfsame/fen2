(var binser (require "deps/binser"))

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

{:write-data write-data
 :read-data read-data
 :write-bin write-bin
 :read-bin read-bin}