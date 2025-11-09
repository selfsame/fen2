(load_img  "default_icon32.png")

(fn update [dt]
  (print "updating..")
  (draw_text "hello world"  10 10 true))

(print "hello-world")

{:update update}
