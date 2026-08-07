package.path = "./?.lua;./?/init.lua;" .. package.path

dofile("tests/waves_boss_adds_test.lua")
dofile("tests/campaign_wave_balance_test.lua")
