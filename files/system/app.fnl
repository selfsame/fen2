

(var testapp (launch_process "../testapp"))

(print "??" testapp)

(fn update [dt]
  (update_process testapp dt))

(fn handle_quit [pid]
  (print "handle_quit" pid)
  (close_process pid))

{:update update
 :handle_quit handle_quit}