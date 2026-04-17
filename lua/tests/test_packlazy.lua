local expect, eq = MiniTest.expect, MiniTest.expect.equality
local child = require("tests.helpers").new_child_neovim()

before_each(function()
	child.setup()
end)

teardown(function()
	child.stop()
end)

describe("packlazy", function()
	it("works", function()
		child.lua([[M.run()]])
		local output = child.cmd_capture("messages")
		expect.equality(output, "Hello from packlazy!")
	end)
end)
