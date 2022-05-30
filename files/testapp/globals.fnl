(var util (require "util"))
(var grid (require "grid"))

(set _G.state (or _G.state (util.read-bin "state.data") {
  :world (grid.make 256 256 -1)
  :background (grid.make 256 256 -1)}))

(set _G.mode :menu)

{:state _G.state :mode _G.mode}