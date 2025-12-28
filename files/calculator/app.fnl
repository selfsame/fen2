(load_img "button.png")
(load_img "error.png")

(var keys ["C" "()" "%" "/" "7" "8" "9" "*" "4" "5" "6" "-" "1" "2" "3" "+" "0" "." "D" "="])
(var input "")
(var error false)

(fn substr-count [s pattern] (# (icollect [n (string.gmatch s pattern)] n)))

(fn handle-input [button]
  (case button
    "C" (set input "")
    "D" (set input (string.sub input 1 -2))
    "()" (let [open (substr-count input "%(")
               closed (substr-count input "%)")]
            (set input (.. input (if (= (string.sub input -1) "(") "(" (if (> open closed) ")" "(")))))
    "=" (let [(ok res) (pcall (load (.. "return " input)))]
          (if ok (set input (.. res)))
          (set error (not ok)))
    _ (set input (.. input button))))

(fn update []
  (clear_screen)
  (let [(tx ty) (measure_text input)]
    (draw_text input (- 93 3 tx) 15 true)
    (if error (draw_img "error.png" 3 3))
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
            (draw_rect (+ bx 1) (+ by 1) 16 16 true)
            (if (mouse_released 1) (handle-input button)))
          (draw_text button (+ bx 10 (* bw -0.5)) (+ by 13) (if hover? false true)))))))

{:update update}
