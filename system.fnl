(fn reload [module-name]
    (let [old (require module-name)
        _ (tset package.loaded module-name nil)
        new (require module-name)]
        ;; if the module isnt a table then we can't make
        ;; changes which affect already-loaded code, but if
        ;; it is then we should splice new values into the
        ;; existing table and remove values that are gone.
        (when (= (type new) :table)
            (each [k v (pairs new)]
                (tset old k v))
            (each [k (pairs old)]
                ;; the elisp reader is picky about where . can be
                (when (not (. new k))
                    (tset old k nil)))
            (tset package.loaded module-name old))
        (require module-name)))

; looks for packages to reload similar to the path string
; this won't work for combinations of '.' and '/'
(fn reload_path [path]
  (let [stripped (string.gsub (string.gsub (string.gsub (string.gsub path "^/" "") "^\\" "") ".fnl$" "") ".lua$" "")
        dotted (string.gsub (string.gsub stripped "\\" ".") "/" ".")
        slashed (string.gsub stripped "\\" "/")]
    (if (. package.loaded dotted)
        (reload dotted))
    (if (and (not (= dotted slashed)) 
             (. package.loaded slashed))
        (reload slashed))))

(fn global_path_loader [f]
  (fn []))

{:reload reload
 :reload_path reload_path}
