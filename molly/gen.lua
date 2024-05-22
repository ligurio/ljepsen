---- Module with functions for generators.
-- @module molly.gen
--
-- One of the key pieces of a Molly test is a generators for client and
-- nemesis operations. These generators will create a finite or infinite
-- sequence of operations. It is often test have its own nemesis generator, but
-- most likely shares a common client generator with other tests. A nemesis
-- generator, for instance, might be a sequence of partition, sleep, and
-- restore, repeated infinitely. A client generator will specify a random,
-- infinite sequence of client operation, as well as the associated parameters
-- such as durability level, the document key, the new value to write or CAS
-- (Compare-And-Set), etc. When a test starts, the client generator feeds
-- client operations to the client and the nemesis generator feeds operations
-- to the nemesis. The test will continue until either the nemesis generator
-- has completed a specified number of operations, a time limit is reached, or
-- an error is thrown.
--
-- Example of generator that generates two operations `w` and `r`:
--
--    local w = function() return { f = 'w', v = math.random(1, 10) } end
--    local r = function() return { f = 'r', v = nil } end
--    gen.rands(0, 2):map(function(x)
--                            return (x == 0 and r()) or
--                                   (x == 1 and w()))
--                        end):take(100)
--
--    local w = function(x) return { f = 'w', v = x } end
--    gen.map(w, gen.rands(1, 10):take(50))
--
--### References:
--
-- - [Lua Functional Library documentation](https://luafun.github.io/)
-- - [Lua Functional Library documentation: Under the Hood](https://luafun.github.io/under_the_hood.html)
-- - [Lua iterators tutorial](http://lua-users.org/wiki/IteratorsTutorial)
-- - [Jepsen generators in a nutshell](http://jepsen-io.github.io/jepsen/jepsen.generator.html)
--
-- @see molly.op

local fun = require('fun')
local clock = require('molly.clock')

local methods = {}
local exports = {}

local iterator_mt = {
    __call = function(self, param, state)
        return self.gen(param, state)
    end,
    __index = methods,
    __tostring = function(self)
        return '<generator>'
    end
}

local wrap = function(gen, param, state)
    return setmetatable({
        gen = gen,
        param = param,
        state = state
    }, iterator_mt), param, state
end
exports.wrap = wrap

local unwrap = function(self)
    return self.gen, self.param, self.state
end
methods.unwrap = unwrap

-- Helpers

local nil_gen = function(_param, _state) -- luacheck: no unused
    return nil
end

--- Basic Functions
-- @section

--- Make an iterator from the iterable object.
-- See [fun.iter](https://luafun.github.io/basic.html#fun.iter).
--
-- @param object - an iterable object (map, array, string).
-- @return an iterator
-- @usage
-- > for _it, v in gen.iter({1, 2, 3}) do print(v) end
-- 1
-- 2
-- 3
-- ---
-- ...
--
-- > for _it, v in gen.iter({a = 1, b = 2, c = 3}) do print(v) end
-- b
-- a
-- c
-- ---
-- ...
--
-- > for _it, v in gen.iter("abc") do print(v) end
-- a
-- b
-- c
-- ---
-- ...
--
--- @function iter
local iter = fun.iter
exports.iter = iter

--- Execute the function `fun` for each iteration value.
-- See [fun.each](https://luafun.github.io/basic.html#fun.each).
-- @param function
-- @param iterator - an iterator or iterable object
-- @return none
-- @usage
--
-- > gen.each(print, { a = 1, b = 2, c = 3})
-- b       2
-- a       1
-- c       3
-- ---
-- ...
--
-- @function each
local each = fun.each
methods.each = each
exports.each = each
--- An alias for each().
-- See `gen.each`.
-- @function for_each
methods.for_each = each
exports.for_each = each
--- An alias for each().
-- See `gen.each`.
-- @function foreach
methods.foreach = each
exports.foreach = each

--- Generators: Finite Generators
-- @section

--- The iterator to create arithmetic progressions.
-- Iteration values are generated within closed interval `[start, stop]` (i.e.
-- `stop` is included). If the `start` argument is omitted, it defaults to 1 (`stop
-- > 0`) or to -1 (`stop < 0`). If the `step` argument is omitted, it defaults to 1
-- (`start <= stop`) or to -1 (`start > stop`). If `step` is positive, the last
-- element is the largest `start + i * step` less than or equal to `stop`; if `step`
-- is negative, the last element is the smallest `start + i * step` greater than
-- or equal to `stop`. `step` must not be zero (or else an error is raised).
-- `range(0)` returns empty iterator.
-- See [fun.range](https://luafun.github.io/generators.html#fun.range).
--
-- @number[opt] start – an endpoint of the interval.
-- @number stop – an endpoint of the interval.
-- @number[opt] step – a step.
-- @return an iterator
--
-- @usage
-- > for _it, v in gen.range(1, 6) do print(v) end
-- 1
-- 2
-- 3
-- 4
-- 5
-- 6
-- ---
-- ...
--
-- > for _it, v in gen.range(1, 6, 2) do print(v) end
-- 1
-- 3
-- 5
-- ---
-- ...
--
-- @function range
local range = fun.range
exports.range = range

--- Generators: Infinity Generators
-- @section

--- The iterator returns values over and over again indefinitely. All values
-- that passed to the iterator are returned as-is during the iteration.
-- See [fun.duplicate](https://luafun.github.io/generators.html#fun.duplicate).
--
-- @usage
-- > gen.each(print, gen.take(3, gen.duplicate('a', 'b', 'c')))
-- a       b       c
-- a       b       c
-- a       b       c
-- ---
-- ...
--
-- @function duplicate
local duplicate = fun.duplicate
exports.duplicate = duplicate
--- An alias for duplicate().
-- @function xrepeat
-- See `gen.duplicate`.
exports.xrepeat = duplicate
--- An alias for duplicate().
-- @function replicate
-- See `gen.duplicate`.
exports.replicate = duplicate

--- Return `fun(0)`, `fun(1)`, `fun(2)`, ... values indefinitely.
-- @function tabulate
-- See [fun.tabulate](https://luafun.github.io/generators.html#fun.tabulate).
local tabulate = fun.tabulate
exports.tabulate = tabulate

--- Generators: Random sampling
-- @section

--- @function rands
-- See [fun.rands](https://luafun.github.io/generators.html#fun.rands).
local rands = fun.rands
methods.rands = rands
exports.rands = rands

--- Slicing: Subsequences
-- @section

--- @function take_n
-- See [fun.take_n](https://luafun.github.io/slicing.html#fun.take_n).
local take_n = fun.take_n
methods.take_n = take_n
exports.take_n = take_n

--- @function take_while
-- See [fun.take_while](https://luafun.github.io/slicing.html#fun.take_while).
local take_while = fun.take_while
methods.take_while = take_while
exports.take_while = take_while

--- @function take
-- See [fun.take](https://luafun.github.io/slicing.html#fun.take).
local take = fun.take
methods.take = take
exports.take = take

--- @function drop_n
-- See [fun.drop_n](https://luafun.github.io/slicing.html#fun.drop_n).
local drop_n = fun.drop_n
methods.drop_n = drop_n
exports.drop_n = drop_n

--- @function drop_while
-- See [fun.drop_while](https://luafun.github.io/slicing.html#fun.drop_while).
local drop_while = fun.drop_while
methods.drop_while = drop_while
exports.drop_while = drop_while

--- @function drop
-- See [fun.drop](https://luafun.github.io/slicing.html#fun.drop).
local drop = fun.drop
methods.drop = drop
exports.drop = drop

--- @function span
-- See [fun.span](https://luafun.github.io/slicing.html#fun.span).
local span = fun.span
methods.span = span
exports.span = span
--- An alias for span().
-- See `fun.span`.
-- @function split
methods.split = span
exports.split = span
--- An alias for span().
-- See `fun.span`.
-- @function split_at
methods.split_at = span
exports.split_at = span

--- Indexing
-- @section

--- @function index
-- See [fun.index](https://luafun.github.io/indexing.html#fun.index).
local index = fun.index
methods.index = index
exports.index = index
--- An alias for index().
-- See `fun.index`.
-- @function index_of
methods.index_of = index
exports.index_of = index
--- An alias for index().
-- See `fun.index`.
-- @function elem_index
methods.elem_index = index
exports.elem_index = index

--- @function indexes
-- See [fun.indexes](https://luafun.github.io/indexing.html#fun.indexes).
local indexes = fun.indexes
methods.indexes = indexes
exports.indexes = indexes
--- An alias for indexes().
-- See `fun.indexes`.
-- @function indices
methods.indices = indexes
exports.indices = indexes
--- An alias for indexes().
-- See `fun.indexes`.
-- @function elem_indexes
methods.elem_indexes = indexes
exports.elem_indexes = indexes
--- An alias for indexes().
-- See `fun.indexes`.
-- @function elem_indices
methods.elem_indices = indexes
exports.elem_indices = indexes

--- Filtering
-- @section

--- Return a new iterator of those elements that satisfy the `predicate`.
-- See [fun.filter](https://luafun.github.io/filtering.html#fun.filter).
-- @function filter
local filter = fun.filter
methods.filter = filter
exports.filter = filter
--- An alias for filter().
-- See `gen.filter`.
-- @function remove_if
methods.remove_if = filter
exports.remove_if = filter

--- If `regexp_or_predicate` is string then the parameter is used as a regular
-- expression to build filtering predicate. Otherwise the function is just an
-- alias for gen.filter().
-- @function grep
-- See [fun.grep](https://luafun.github.io/filtering.html#fun.grep).
local grep = fun.grep
methods.grep = grep
exports.grep = grep

--- The function returns two iterators where elements do and do not satisfy the
-- predicate.
-- @function partition
-- See [fun.partition](https://luafun.github.io/filtering.html#fun.partition).
local partition = fun.partition
methods.partition = partition
exports.partition = partition

--- Reducing: Folds
-- @section

--- The function reduces the iterator from left to right using the binary
-- operator `accfun` and the initial value `initval`.
-- @function foldl
-- See [fun.foldl](https://luafun.github.io/reducing.html#fun.foldl).
local foldl = fun.foldl
methods.foldl = foldl
exports.foldl = foldl
--- An alias to foldl().
-- See `gen.foldl`.
-- @function reduce
methods.reduce = foldl
exports.reduce = foldl

--- Return a number of elements in `gen, param, state` iterator.
-- @function length
-- See [fun.length](https://luafun.github.io/reducing.html#fun.length).
local length = fun.length
methods.length = length
exports.length = length

--- Return a new table (array) from iterated values.
-- @function totable
-- See [fun.totable](https://luafun.github.io/reducing.html#fun.totable).
local totable = fun.totable
methods.totable = totable
exports.totable = totable

--- Return a new table (map) from iterated values.
-- @function tomap
-- See [fun.tomap](https://luafun.github.io/reducing.html#fun.tomap).
local tomap = fun.tomap
methods.tomap = tomap
exports.tomap = tomap

--- Reducing: Predicates
-- @section

--- @function is_prefix_of
-- See [fun.is_prefix_of](https://luafun.github.io/reducing.html#fun.is_prefix_of).
local is_prefix_of = fun.is_prefix_of
methods.is_prefix_of = is_prefix_of
exports.is_prefix_of = is_prefix_of

--- @function is_null
-- See [fun.is_null](https://luafun.github.io/reducing.html#fun.is_null).
local is_null = fun.is_null
methods.is_null = is_null
exports.is_null = is_null

--- @function all
-- See [fun.all](https://luafun.github.io/reducing.html#fun.all).
local all = fun.all
methods.all = all
exports.all = all

--- An alias for all().
-- See `fun.all`.
-- @function every
methods.every = all
exports.every = all

--- @function any
-- See [fun.any](https://luafun.github.io/reducing.html#fun.any).
local any = fun.any
methods.any = any
exports.any = any
--- An alias for any().
-- See `fun.any`.
-- @function some
methods.some = any
exports.some = any

--- Transformations
-- @section

--- @function map
-- See [fun.map](https://luafun.github.io/transformations.html#fun.map).
local map = fun.map
methods.map = map
exports.map = map

--- @function enumerate
-- See [fun.enumerate](https://luafun.github.io/transformations.html#fun.enumerate).
local enumerate = fun.enumerate
methods.enumerate = enumerate
exports.enumerate = enumerate

--- @function intersperse
-- See [fun.intersperse](https://luafun.github.io/transformations.html#fun.intersperse).
local intersperse = fun.intersperse
methods.intersperse = intersperse
exports.intersperse = intersperse

--- Compositions
-- @section

--- Return a new iterator where i-th return value contains the i-th element
-- from each of the iterators. The returned iterator is truncated in length to
-- the length of the shortest iterator. For multi-return iterators only the
-- first variable is used.
-- See [fun.zip](https://luafun.github.io/compositions.html#fun.zip).
-- @param ... - an iterators
-- @return an iterator
-- @function zip
local zip = fun.zip
methods.zip = zip
exports.zip = zip

--- A cycled version of an iterator.
-- Make a new iterator that returns elements from `{gen, param, state}` iterator
-- until the end and then "restart" iteration using a saved clone of `{gen,
-- param, state}`. The returned iterator is constant space and no return values
-- are buffered. Instead of that the function make a clone of the source `{gen,
-- param, state}` iterator. Therefore, the source iterator must be pure
-- functional to make an indentical clone. Infinity iterators are supported,
-- but are not recommended.
-- @param iterator - an iterator
-- @return an iterator
-- See [fun.cycle](https://luafun.github.io/compositions.html#fun.cycle).
-- @function cycle
local cycle = fun.cycle
methods.cycle = cycle
exports.cycle = cycle

--- Make an iterator that returns elements from the first iterator until it is
-- exhausted, then proceeds to the next iterator, until all of the iterators are
-- exhausted. Used for treating consecutive iterators as a single iterator.
-- Infinity iterators are supported, but are not recommended.
-- See [fun.chain](https://luafun.github.io/compositions.html#fun.chain).
-- @param ... - an iterators
-- @return an iterator, a consecutive iterator from sources (left from right).
-- @usage
-- > fun.each(print, fun.chain(fun.range(5, 1, -1), fun.range(1, 5)))
-- 5
-- 4
-- 3
-- 2
-- 1
-- 1
-- 2
-- 3
-- 4
-- 5
-- ---
-- ...
--
-- @function chain
local chain = fun.chain
methods.chain = chain
exports.chain = chain

--- (TODO) Cycles between several generators on a rotating schedule.
-- Takes a flat series of [time, generator] pairs.
-- @param ... - an iterators
-- @return an iterator
-- @function cycle_times
local cycle_times = function()
    -- TODO
end
methods.cycle_times = cycle_times

--- (TODO) A random mixture of several generators. Takes a collection of generators
-- and chooses between them uniformly.
--
-- To be precise, a mix behaves like a sequence of one-time, randomly selected
-- generators from the given collection. This is efficient and prevents
-- multiple generators from competing for the next slot, making it hard to
-- control the mixture of operations.
--
-- @param ... - an iterators
-- @return an iterator
-- @function mix
local mix = function()
    -- TODO
end
methods.mix = mix
exports.mix = mix

--- (TODO) Emits an operation from generator A, then B, then A again, then B again,
-- etc. Stops as soon as any gen is exhausted.
-- @number a generator A.
-- @number b generator B.
-- @return an iterator
--
-- @function flip_flop
local flip_flop = (function()
    -- TODO
end)
methods.flip_flop = flip_flop

--- Special generators
-- @section

--- (TODO) A generator which, when asked for an operation, logs a message and yields
--  nil. Occurs only once; use `repeat` to repeat.
-- @return an iterator
--
-- @function log
local log = function()
    -- TODO
end
exports.log = log

--- (TODO) Operations from that generator are scheduled at uniformly random intervals
-- between `0` to `2 * (dt seconds)`.
-- @number dt Number of seconds.
-- @return an iterator
--
-- @function stagger
local stagger = (function()
    -- TODO
end)
methods.stagger = stagger

--- Stops generating items when time limit is exceeded.
-- @number duration Number of seconds.
-- @return an iterator
--
-- @usage
-- >  for _it, v in gen.time_limit(gen.range(1, 100), 0.0001) do print(v) end
-- 1
-- 2
-- 3
-- 4
-- 5
-- 6
-- 7
-- 8
-- 9
-- 10
-- 11
-- 12
-- ---
-- ...
--
-- @function time_limit
local time_limit = (function(fn)
    return function(self, arg1)
        return fn(arg1, self.gen, self.param, self.state)
    end
end)(function(timeout, gen, param, state)
    if type(timeout) ~= 'number' or timeout == 0 then
        error("bad argument with duration to time_limit", 2)
    end
    local get_time = clock.monotonic
    local start_time = get_time()
    local time_is_exceed = false
    return wrap(function(ctx, state_x)
        local gen_x, param_x, duration, cnt = ctx[1], ctx[2], ctx[3], ctx[4] + 1
        ctx[4] = cnt
        if time_is_exceed == false then
            time_is_exceed = get_time() - start_time >= duration
            return gen_x(param_x, state_x)
        end
        return nil_gen(nil, nil)
    end, {gen, param, timeout, 0}, state)
end)
methods.time_limit = time_limit
exports.time_limit = time_limit

return exports
