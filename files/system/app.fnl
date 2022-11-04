(var apps {})

(fn start []
  (print "system starting..")
  (tset apps (launch_process "../testapp") true)
  (tset apps (launch_process "../testapp") true))

(fn update [dt]
  (each [app _ (pairs apps)] 
    (update_process app dt)))

(fn handle_quit [pid]
  (print "handle_quit" pid)
  
  (tset apps pid nil)
  (print (fennel.view apps))
  (close_process pid))

{:start start
 :update update
 :handle_quit handle_quit}