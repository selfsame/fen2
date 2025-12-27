(load_img "button.png")

(var keys ["C" "()" "%" "/" "7" "8" "9" "*" "4" "5" "6" "-" "1" "2" "3" "+" "0" "." "D" "="])

(fn update []
  (clear_screen)

  (let [s "14.0123770"
        (tx ty) (measure_text s)]
    (draw_text s (- 93 3 tx) 15 true))
  (for [y 1 5]
    (for [x 1 4]
      (let [i (+ x (* (- y 1) 4))
            button (. keys i)
            (bw _) (measure_text button)
            bx (+ (* (- x 1) 22) 4)
            by (+ (* (- y 1) 22) 21)
            (mx my) (mouse_pos)
            hover? (and (< bx mx (+ bx 18)) (< by my (+ by 18)))]
        (draw_9patch "button.png" 2 4 2 4 bx by 19 19)
        (when hover?
          (draw_rect (+ bx 1) (+ by 1) 16 16 true))
        (draw_text button (+ bx 10 (* bw -0.5)) (+ by 13) (if hover? false true))))))

{:update update}
