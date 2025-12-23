(require "globals")
(var v (require "v"))
(var dungeon (require "dungeon"))

(load_img "sprites.png")

(set _G.prn (fn prn [x] (print (fennel.view x))))
(var prn _G.prn)

(macro global [symbol value]
  ;`(var ,sym (do (set _G.,sym ,value) ,value))
  `(var ,symbol (do (tset _G.,symbol ,value) ,value)))

(macro fixed [some-table]
  `(do
    ;; The unpacked table is at the end its list, so it is fully expanded.
    (do ,(unpack some-table))
    (print "hello")))

(macrodebug (global v2 v.v2))

;(use "v" v2 vadd)



(fn new-game []
  (set _G.player {})
  (set _G.depth 0)
  (set _G.need_redraw true)
  (set _G.current_level (dungeon.make-level)))

(new-game)

(fn draw-map [m]
  (each [y row (pairs m.grid)]
    (each [x val (pairs row)]
      (match val
        1 (draw_rect_lines (* x 4) (* y 4) 4 4 true) ;(draw_img "sprites.png" (* x 4) (* y 4) 0 0 16 16 4 4))
      ))))


(fn update [dt]
  (when _G.need_redraw
    (clear_screen false)
    (set _G.need_redraw false)
    (print "redraw")
    (draw-map _G.current_level)))

(fn message [payload]
  (print "??"))

{:update update}
