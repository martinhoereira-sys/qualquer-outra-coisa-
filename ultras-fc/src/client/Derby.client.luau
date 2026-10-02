--!strict
--[[
	Today's derby on this screen.

	The interface is built with the clubs of Derby 1. Once it exists, every
	label and colour that belongs to a club is remembered, and from then on
	the server's derby (workspace attribute "Derby") repaints it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Derby = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Derby"))

local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
-- Give the other scripts a moment to build their screens.
gui:WaitForChild("UltrasHud", 10)
task.wait(1)
Derby.follow({ gui })
