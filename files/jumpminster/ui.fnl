(var v (require "v"))

(fn button [x y w h label f]
  (let [(mx my) (mouse_pos)
        over? (v.v_in_rect (v.v2 mx my) (v.v2 x y) (v.v2 (+ x w) (+ y h)))
        color (if over? true false)]
    (draw_rect x y w h color)
    (draw_rect_lines x y w h 1 (not color))
    (draw_text label (+ x (/ w 2) (* (/ (# label) 2) -6)) (+ y (/ h 2) 3) (not color))
    (when (and over? (mouse_pressed 1)) (play_sound "audio/blip.wav" false 0.3) (f))))

(fn checkbox [x y label checked f]
  (let [(mx my) (mouse_pos)
        width (* (# label) 10)
        over? (v.v_in_rect (v.v2 mx my) (v.v2 x y) (v.v2 (+ x width) (+ y 16)))
        ]
    (draw_rect x y 16 16 true)
    (draw_rect (+ x 1) (+ y 1) 14 14 false)
    (when checked (draw_rect (+ x 2) (+ y 2) 12 12 true))
    (draw_text label (+ x 20) (+ y 11) true)
    (when (and over? (mouse_pressed 1)) (play_sound "audio/blip.wav" false 0.3) (f))))

(fn icon-bar [cnt max x y width sprite]
  (let [spr-pos (v.vmul sprite 16)
        fill-pos (v.vadd spr-pos (v.v2 16 0))]
    (for [i 0 (- max 1)]
      (let [iy (math.floor (/ i width))
            ix (% i width)
            spr (if (< i cnt) fill-pos spr-pos)]
      (draw_sprite "entities.png"
        (+ x (* ix 12)) (+ y (* iy 12)) spr.x spr.y 16 16)))))

{:button button :checkbox checkbox :icon-bar icon-bar}