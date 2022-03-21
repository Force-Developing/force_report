local group 

RegisterNetEvent('reply:setGroup')
AddEventHandler('reply:setGroup', function(g)
	print('group setted ' .. g)
	group = g
end)