(var util (require "util"))
(var grid (require "grid"))

(set _G.state (or _G.state (util.read-bin "state.data") {
  :world (grid.make 256 256 -1)
  :background (grid.make 256 256 -1)
  :entities []}))

(set _G.view_bucket {:size 600 :prop "pos"})
(set _G.collision_bucket {:size 16 :prop "pos"})

(set _G.mode :menu)

(set _G.mouse_bad 0)



{:state _G.state :mode _G.mode}