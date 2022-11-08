_9 = {}

function del(col, o) 
  local found = false
  for i,v in ipairs(col) do 
    if v == o and found == false then 
      table.remove(col, i)
      found = true
    end
  end
end

function point(x,y) return {x=x,y=y} end
for x=-1,1 do for y=-1,1 do table.insert(_9,point(x,y)) end end
function p_str(p) return p.x..","..p.y end
function coords(p, s) return point(math.floor(p.x*(1/s)),math.floor(p.y*(1/s))) end

function str_p(s)
  for i=1,#s do if sub(s,i,i) == "," then
    return point(sub(s, 1, i-1)+0, sub(s, i+1, #s)+0)
end end end

function badd(k,e,_b)
  _b[k] = _b[k] or {} 
  table.insert(_b[k], e)
end

function bdel(_b, e)
  local k = e["_k".._b.size]
  if k then
    local b = _b[k]
    if b then 
      del(b,e)
      if (#b == 0) then _b[k]=nil end
    end
  end
end

function bstore(_b,e)
  local p = p_str(coords(e[_b.prop],_b.size))
  local k = e["_k".._b.size]
  if k then
    if (k ~= p) then
      local b = _b[k]
      if b then
        del(b,e)
        if (#b == 0) then _b[k]=nil end
      end
      badd(p,e,_b)
    end
  else badd(p,e,_b) end
  e["_k".._b.size] = p
end

function bget(_b, p)
  local p = coords(p, _b.size)
  local _ = {}
  for i, o in ipairs(_9) do
    local found = _b[p_str(point(p.x+o.x,p.y+o.y))]
    if found then for i, e in ipairs(found) do table.insert(_,e) end end
  end
  return _
end

return {bstore=bstore, bget=bget, bdel=bdel}

-- usage

-- create a data 'store' {size=30,prop="pos"}
-- store.prop should match your entities' position property name, 
-- which should be a 'point' value like {x=0,y=0}
-- store.size should be tuned to the max neighbor distance you'll be finding

-- periodically call bstore(store, entity) to update their bucket membership

-- bget(store, point) returns stored entities from a 3x3 square of buckets around 
-- the given point, filter these by a distance function if you need more precision

-- bdel(store, entity) to remove an entity

-- remember you can maintain multiple stores based on the needs of your game!