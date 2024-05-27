---- Module with default Molly client.
-- @module molly.client
--
-- @see molly.gen
-- @see molly.tests

local clock = require('molly.clock')
local dev_checks = require('molly.dev_checks')
local log = require('molly.log')
local op_lib = require('molly.op')

local shared_gen_state
local op_index = 1

local function process_operation(client, history, op, thread_id_str, thread_id)
    dev_checks('<client>', '<history>', 'function|table', 'string', 'number')

    if type(op) == 'function' then -- FIXME: check for callable object
        op = op()
    end

    assert(type(op) == 'table', 'Type of operation is not a Lua table.')

    op.type = 'invoke'
    op.process = thread_id
    op.index = op_index
    op_index = op_index + 1
    op.time = clock.monotonic64()
    log.debug('%-4s %s', thread_id_str, op_lib.to_string(op))
    history:add(op)
    local ok, res = pcall(client.invoke, client, op)
    if not ok then
        log.warn('Process %d crashed (%s)', thread_id, res)
        res.type = 'fail'
        return
    end
    if res.type == nil then
        error('Operation type is empty.')
    end
    res.index = op_index
    op_index = op_index + 1
    res.process = thread_id
    res.time = clock.monotonic64()
    log.debug('%-4s %s', thread_id_str, op_lib.to_string(res))
    history:add(res)
end

local function invoke(thread_id, opts)
    dev_checks('number', 'table')

    local client = opts.client
    local ops_generator = opts.gen
    local history = opts.history

    local nth = math.random(1, table.getn(opts.nodes)) -- TODO: Use fun.cycle() and closure.
    local addr = opts.nodes[nth]

    log.debug('Opening connection by thread %d to DB (%s)', thread_id, addr)
    local ok, err = pcall(client.open, client, addr)
    if not ok then
        log.info('ERROR: %s', err)
        return false, err
    end

    log.debug('Setting up DB (%s) by thread %d', addr, thread_id)
    ok, err = pcall(client.setup, client)
    if not ok then
        log.info('ERROR: %s', err)
        return false, err
    end

    -- TODO: Add barrier here.

    local gen, param, state = ops_generator:unwrap()
    shared_gen_state = state
    local op
    local thread_id_str = '[' .. tostring(thread_id) .. ']'
    while true do
        state, op = gen(param, shared_gen_state)
        if state == nil then
            break
        end
        shared_gen_state = state
        ok, err = pcall(process_operation, client, history, op, thread_id_str, thread_id)
        if ok == false then
            error('Failed to process an operation', err)
        end

        require('fiber').yield()
    end

    -- TODO: Add barrier here.

    log.debug('Tearing down DB (%s) by thread %d', addr, thread_id)
    ok, err = pcall(client.teardown, client)
    if not ok then
        log.info('ERROR: %s', err)
        return false, err
    end

    log.debug('Closing connection to DB (%s) by thread %d', addr, thread_id)
    ok, err = pcall(client.close, client)
    if not ok then
        log.info('ERROR: %s', err)
        return false, err
    end

    return true, nil
end

-- https://www.lua.org/pil/16.2.html

local client_mt = {
    __type = '<client>',
    __index = {
        open = function() return true end,
        setup = function() return true end,
        invoke = function() return {} end,
        teardown = function() return true end,
        close = function() return true end,
    }
}

--- Function that returns a default client implementation.
--
-- Default implementation of a client defines open, setup, teardown and close
-- methods with empty implementation that always returns true.
--
-- Client must implement the following methods:
--
-- **open** - function that open a connection to a database instance. Function
-- must return a boolean value, true in case of success and false otherwise.
--
-- **setup** - function that set up a database instance. Function must return a
-- boolean value, true in case of success and false otherwise.
--
-- **invoke** - function that accept an operation and invoke it on database
-- instance, function should process user-defined types of operations and
-- execute intended actions on databases. Function must return an operation
-- after invokation.
--
-- **teardown** - function that tear down a database instance. Function must
-- return a boolean value, true in case of success and false otherwise.
--
-- **close** - function that close connection to a database instance. Function
-- must return a boolean value, true in case of success and false otherwise.
--
-- In general it is recommended to raise an error in case of fatal errors like
-- failed database setup, teardown or connection and set status of operation to
-- 'fail' when key is not found in database table etc.
--
-- @return client
-- @usage
-- local client = require('molly').client.new()
-- client.invoke = function(op)
--     return true
-- end
--
-- @function new
local function new()
    return setmetatable({
        storage = {},
    }, client_mt)
end

return {
    new = new,

    invoke = invoke,        -- A wrapper for user-defined invoke.
}
