-- ----------------------------------------------------------------------------
-- "THE BEER-WARE LICENSE" (Revision 42):
-- <xico@simbio.se> wrote this file. As long as you retain this notice you
-- can do whatever you want with this stuff. If we meet some day, and you think
-- this stuff is worth it, you can buy me a beer in return
-- ----------------------------------------------------------------------------

local co, os, st = require('coroutine'), require('os'), require('string')
local _, ffi = pcall(require, 'ffi')

local create, yield, resume, status, time, execute, format =
      co.create, co.yield, co.resume, co.status, os.time, os.execute, st.format

local sleep
if _ then
  ffi.cdef[[void Sleep(int ms);
  int poll(struct pollfd *fds, unsigned long nfds, int timeout);]]

  if ffi.os == 'Windows' then
    function sleep(s) ffi.C.Sleep((s * 1000)) end
  else
    function sleep(s) ffi.C.poll(nil, 0, (s * 1000)) end
  end
else
  function sleep(s) execute('sleep ' .. tonumber(s)) end
end

co, os, st = nil, nil, nil

local puraki, routine = {}, {}

local function Routine(task, index, env)
  local this = {
    task      = nil,
    coroutine = nil,
    time      = 0,
    idle_time = 0,
    status    = 1, -- 0 running, 1 stopped, 2 waiting (to resume), 3 error
    cause     = '',
    context   = {
        idle_time = 60,
        ttl       = 0,
        task      = index,
        cicles    = 1,
        boots     = 1,
        keep      = false,
        interval  = -1
      }
  }

  setmetatable(this, {__index = routine})
  this:bootstrap(task, false)
  return this
end

function routine:continue()
  if (self.coroutine and status(self.coroutine) == 'suspended') then
    self.status = 0
    resume(self.coroutine, self)
  end
end

function routine:keep()
  return (self.context.keep)
end

function routine:dead()
  return (not self.coroutine or status(self.coroutine) == 'dead')
end

function routine:stopped()
  return (self.status == 1)
end

function routine:running()
  return (self.status == 0)
end

function routine:waiting()
  return (self.status == 2)
end

function routine:error()
  return (self.status == 3)
end

function routine:debug()
  print(self.status, status(self.coroutine), self:idle(), self:expired())
end

function routine:expired()
  return (self.context.ttl > 0 and self.context.ttl < time())
end

function routine:idle()
  return (self.idle_time < time())
end

function routine:manager()
  local not_err, cause

  local function continue()
    self:continue()
  end

  while true do
    self.idle_time = (time() + self.context.idle_time)
    self.status    = 0

    not_err, cause = pcall(self.task, self.context, continue)

    if not not_err then
      self.status = 3
      self.cause  = format("%d: %s", time(), tostring(cause))
    end

    if self:expired() or self:error() or (not_err and cause == false) then
      self.status = 1
      return true
    elseif not_err and cause == true then
      self.status = 2
    end

    yield()

    self.context.cicles = (self.context.cicles + 1)
  end
end

function routine:bootstrap(scope, run_it)
  if scope then
    local task = scope(self.context)

    if 'function' ~= type(task) then
      return false
    else
      self.task = task
    end
  end

  self.context.time   = time()
  self.context.status = 0
  self.context.boots  = (self.context.boots + 1)
  if self.context.ttl > 0 then
    self.context.ttl = (self.context.time + self.context.ttl)
  end

  self.coroutine = create(self.manager)
  if run_it then
    resume(self.coroutine, self)
  end

  return true
end


--[[

]]

-- create a loop/sentinel
local function loop(tasks)
  local all_dead = true
  local index, routine

  while true do
    all_dead = true

    for index, routine in ipairs(tasks) do
      if routine:dead() then
        if routine:keep() then
          all_dead = false
          routine:bootstrap(nil, true)
        end
      elseif routine:idle() then
        -- kill!
      elseif routine:waiting() and not routine:expired() then
        all_dead = false
        routine:continue()
      else
        all_dead = false
      end
    end

    sleep(0.01)

    if all_dead then
      return
    end
  end
end


-- create a task
function puraki:task(scope, env)
  if #self.tasks == self.spawn then return end
  local i, x = 0, 0
  for i = (#self.tasks == 0 and 1 or #self.tasks), self.spawn do
    if 'table' == type(scope) then
      for x = 1, #scope do
        self.tasks[(#self.tasks + 1)] = Routine(scope, (#self.tasks + 1))
      end
    else
      self.tasks[(#self.tasks + 1)] = Routine(scope, (#self.tasks + 1))
    end
  end
end

-- run tasks
function puraki:run()
  local index, routine
  for index, routine in ipairs(self.tasks) do
    routine:bootstrap(nil, true)
  end
  loop(self.tasks)
end

-- clear tasks queue
function puraki:clear()
  local i = 0
  for i = 1, #tasks do
    tasks[i] = nil
  end
  tasks = nil
end

local function Puraki()
  local this = {spawn = 1, tasks = {}}
  setmetatable(this, {__index = puraki})
  return this
end

return Puraki