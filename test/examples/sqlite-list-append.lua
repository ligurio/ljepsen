-- https://www.sqlite.org/isolation.html
-- https://www.sqlite.org/threadsafe.html
-- https://www.sqlite.org/atomiccommit.html

local sqlite3 = require('lsqlite3')
local molly = require('molly')
local os = require('os')

print('SQLite version:', sqlite3.version())
print('lsqlite3 library version:', sqlite3.lversion())

local function sqlite_insert(stmt, key, val)
    local ok = stmt:bind_values(key, val)
    if ok ~= sqlite3.OK then
        return false
    end
    ok = stmt:step()
    if ok ~= sqlite3.DONE then
        return false
    end
    stmt:reset()

    return true
end

local function sqlite_select(stmt, key)
    local values = {}
    for row in stmt:nrows() do
        if row.key == key then
            table.insert(values, row.val)
        end
    end
    return values
end

local sqlite_list_append = molly.client.new()

sqlite_list_append.open = function(self)
    self.db = assert(sqlite3.open_memory(), 'database handle is nil')
    if self.db == nil then
        error('database handle is nil')
    end
    -- See explanation in https://www.sqlite.org/pragma.html
    assert(sqlite3.OK == self.db:exec('PRAGMA journal_mode = WAL'))
    assert(sqlite3.OK == self.db:exec('PRAGMA synchronous = normal'))
    assert(sqlite3.OK == self.db:exec('PRAGMA mmap_size = 30000000000'))
    assert(sqlite3.OK == self.db:exec('PRAGMA page_size = 32768'))
    return true
end

sqlite_list_append.setup = function(self)
    assert(sqlite3.OK == self.db:exec('CREATE TABLE IF NOT EXISTS list_append (key INT NOT NULL, val INT)'))
    self.insert_stmt = assert(self.db:prepare('INSERT INTO list_append VALUES (?, ?)'))
    self.select_stmt = assert(self.db:prepare('SELECT key, val FROM list_append ORDER BY key'))
    return true
end

local IDX_MOP_TYPE = 1
local IDX_MOP_KEY = 2
local IDX_MOP_VAL = 3

sqlite_list_append.invoke = function(self, op)
    local mop = op.value[1] -- TODO: Support more than one mop in operation.
    local mop_key = mop[IDX_MOP_KEY]
    local type = 'ok'
    if mop[IDX_MOP_TYPE] == 'r' then
        mop[IDX_MOP_VAL] = sqlite_select(self.select_stmt, mop_key)
    elseif mop[IDX_MOP_TYPE] == 'append' then
        local ok = sqlite_insert(self.insert_stmt, mop_key, mop[IDX_MOP_VAL])
        if ok == false then
            type = 'fail'
        end
    else
        error('Unknown operation')
    end

    return {
        value = { mop },
        f = op.f,
        process = op.process,
        type = type,
    }
end

sqlite_list_append.teardown = function(self)
    --self.insert_stmt:finalize()
    --self.select_stmt:finalize()
    return true
end

sqlite_list_append.close = function(self)
    -- Close database. All SQL statements prepared using
    -- db:prepare() should have been finalized before this
    -- function is called. The function returns sqlite3.OK on
    -- success or else a numerical error code.
    if self.db:isopen() then
        assert(self.db:close() == sqlite3.OK)
    end
    return true
end

local test_options = {
    create_reports = true,
    threads = 1,
}
local ok, err = molly.runner.run_test({
    client = sqlite_list_append,
    generator = molly.gen.time_limit(molly.tests.list_append_gen(), 0.05)
}, test_options)

if not ok then
    print('Test has failed:', err)
end

if os.getenv('DEV') ~= 'ON' then
    os.remove('history.json')
    os.remove('history.txt')
end
