-- ----------------------------------------------------------------------------
-- "THE BEER-WARE LICENSE" (Revision 42):
-- <xxleite@gmail.com> wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, and you think
-- this stuff is worth it, you can buy me a beer in return
-- ----------------------------------------------------------------------------

local ta, co, ti, os = 
  require('table'), require('coroutine'), require('timer'), require('os')

local puraki, set_timeout, clear_timer, set_interval, create, yield,
      resume, status, insert, remove, time = 
      {}, ti.setTimeout, ti.clearTimer, ti.setInterval, co.create, co.yield,
      co.resume, co.status, ta.insert, ta.remove, os.time

co, ta, ti, os = nil, nil, nil, nil

function puraki.new()
  -- body

  local this, contexts, tasks, coroutines, scope, stop, finish, loop =
    {}, {}, {}, {}, function() return end, true, true, nil

  local function continue(index)
    if (coroutines[index] and status(coroutines[index]) == 'suspended') and 
      not stop then
      resume(coroutines[index])
    end
  end

  -- create task also recycle
  local function bootstrap_task(index)
    local context = {
        max_idle_time=60, ttl=0, time=0, task=0,
        cicles=1, keep=false, status='stoped'
      }
    local task = scope(this, context)

    if 'function' ~= type(task) then return false end

    contexts[index] = (contexts[index] or context)
    task[index]     = task

    return true
  end

  -- create a loop/sentinel thru tasks
  local function tasks_loop()

    -- check loop
    if loop then
      return
    end

    -- interval
    loop = set_interval((this.cicle or 500), function()

      local i = 1
      for i = 1, this.parallel do

        if #coroutines == 0 and finish then
          clear_timer(loop)
          loop = nil
        end

        if coroutines[i] then
          if status(coroutines[i]) == 'dead' then
            if finish or (contexts[i] and contexts[i].keep) then
              coroutines[i] = nil
              if (contexts[i] and contexts[i].keep) then
                bootstrap_task(i)
              else
                i = i - 1
              end
            end
          elseif status(coroutines[i]) == 'suspended' and not stop then
            resume(coroutines[i])
          end
        else
          if not stop and not finish then
            create_task(i)
          end
        end
      end
    end)
  end

  -- create and run task
  create_task = function(index)
    local coroutine
    coroutines[index] = coroutine

    -- populate metadata
    contexts[index].time   = time()
    contexts[index].status = 'running'
    contexts[index].task   = index
    if contexts[index].ttl > 0 then
      contexts[index].ttl = (contexts[index].time + contexts[index].ttl)
    end

    local function manager()

      local err, cause = true, ''

      -- task loop
      while true do
        contexts[index].idle_time = (time() + contexts[index].max_idle_time)

        err, cause = pcall(tasks[index], contexts[index])

        if not err then
          contexts[index].error  = cause
          contexts[index].status = 'error'
        else
          if (contexts[index].ttl > 0 and contexts[index].ttl < time()) or 
            cause == true then
            contexts[index].status = 'stop'
          end
        end

        if finish or contexts[index].status ~= 'running' then
          return true
        else
          set_timeout(this.interval, continue, index)
        end

        yield()

        contexts[index].cicle  = contexts[index].cicle + 1
      end
    end

    coroutines[index] = create(manager)
    resume(coroutines[index])
  end

  this = {

    cicle    = 500,
    interval = 400,
    parallel = 20,

    -- create a task
    task = function(self, callback_scope)
      scope = callback_scope
      if #tasks == this.parallel then return end

      local i = 0
      for i = (#tasks == 0 and 1 or #tasks), self.parallel do
        if not bootstrap_task(i) then break end
      end
    end,

    -- resume queue
    resume = function(self)
      stop = false
    end,

    -- stop queue
    stop = function(self)
      stop = true
    end,

    -- run tasks
    run = function(self)
      local i = 1
      stop, finish = false, false
      for i = 1, #tasks do
        create_task(i)
      end
      tasks_loop()
    end,

    -- clear tasks queue
    clear_queue = function(self, ...)
      local options = {...}
      local i, force, callback = 1, (options[1] and options[1] or false), 
                                    (options[2] and options[2] or function() end)

      stop, finish = true, true
      if force then
        for i=1, #coroutines do
          coroutines[i] = nil
          remove(coroutines, i)
          i = i - 1
        end
        callback()
      else
        local cq 
        cq = set_interval((self.cicle || 500), function()
          if #coroutines == 0 then
            clear_timer(cq)
            callback()
          end
        end)
      end
    end
  }

  setmetatable(this, puraki)
  return this
end

return puraki