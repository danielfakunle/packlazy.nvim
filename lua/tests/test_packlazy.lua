local expect, eq = MiniTest.expect, MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

before_each(function()
	child.setup()
end)

teardown(function()
	child.stop()
end)

describe("packlazy", function()
	it("sample", function()
		eq(1, 1)
	end)
end)
