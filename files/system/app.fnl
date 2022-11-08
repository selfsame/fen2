(var apps {})

(fn _find-apps [dir found]
  (let [files (list_files dir)]
    (if (. files "app.fnl")
      (table.insert found dir)
      (each [k v (pairs files)]
          (if (= v "dir")
            (_find-apps (.. dir k "/") found))))))

(fn find-apps [dir]
  (let [found []]
    (_find-apps dir found)
    found))


(print (fennel.view (find-apps "../")))

(fn start []
  (print "system starting..")
  ;(tset apps (launch_process "../testapp") true)
  ;(tset apps (launch_process "../testapp") true)
  
  ;(print (fennel.view io))
  ;(print (fennel.view (list_files "../testapp")))
  )

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