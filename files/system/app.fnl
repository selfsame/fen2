

(var testapp (launch_process "../testapp"))

(print "??" testapp)

(fn update [dt]
  (update_process testapp dt)
  )

{:update update}