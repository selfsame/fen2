(var v (require "v"))

(fn button [x y w h label f]
  (let [(mx my) (mouse_pos)
        over? (v.v_in_rect (v.v2 mx my) (v.v2 x y) (v.v2 (+ x w) (+ y h)))
        color (if over? true false)]
    (draw_rect x y w h color)
    (draw_rect_lines x y w h 1 (not color))
    (draw_text label (+ x (/ w 2) (* (/ (# label) 2) -6)) (+ y (/ h 2) 3) (not color))
    (when (and over? (mouse_pressed 1)) (f))))


{:button button}