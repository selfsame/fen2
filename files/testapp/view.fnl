(var v (require "v"))

; a map drawing module

(fn new [x y w h]
  (let [tl (v.v2 x y)
        wh (v.v2 w h)
        br (v.v2add tl wh)
        tile-wh (v.vdiv wh (v.v2 16 16))]
  {:tl tl
   :wh wh
   :br br
   :camera (v.v2 0 0)}))

(fn screen->tile [view pos])

(fn tile->screen [view tpos])

(fn draw [view])

{:new new}