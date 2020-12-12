ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterCommand('comserv', 'admin', function(xPlayer, args, showError)
	TriggerEvent('esx_communityservice:sendToCommunityService', tonumber(args.playerId.source), tonumber(args.comcount))
end, true, {help = "", validate = true, arguments = {
	{name = 'playerId', help = 'PlayerID!', type = 'player'},
	{name = 'comcount', help = 'Tedad!', type = 'number'}
}})

ESX.RegisterCommand('endcomserv', 'admin', function(xPlayer, args, showError)
	releaseFromCommunityService(args.playerId.source)
end, true, {help = "", validate = true, arguments = {
	{name = 'playerId', help = 'PlayerID!', type = 'player'}
}})

-- unjail after time served
RegisterServerEvent('esx_communityservice:finishCommunityService')
AddEventHandler('esx_communityservice:finishCommunityService', function()
	-- @TODO: Admin Rank check
	releaseFromCommunityService(source)
end)

RegisterServerEvent('esx_communityservice:completeService')
AddEventHandler('esx_communityservice:completeService', function()
	-- @TODO: Admin Rank check
	local _source = source
	local identifier = GetPlayerIdentifiers(_source)[1]

	MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(result)

		if result[1] then
			MySQL.Async.execute('UPDATE communityservice SET actions_remaining = actions_remaining - 1 WHERE identifier = @identifier', {
				['@identifier'] = identifier
			})
		else
			print ("ESX_CommunityService :: Problem matching player identifier in database to reduce actions.")
		end
	end)
end)

RegisterServerEvent('esx_communityservice:extendService')
AddEventHandler('esx_communityservice:extendService', function()

	local _source = source
	local identifier = GetPlayerIdentifiers(_source)[1]

	MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(result)

		if result[1] then
			MySQL.Async.execute('UPDATE communityservice SET actions_remaining = actions_remaining + @extension_value WHERE identifier = @identifier', {
				['@identifier'] = identifier,
				['@extension_value'] = Config.ServiceExtensionOnEscape
			})
		else
			print ("ESX_CommunityService :: Problem matching player identifier in database to reduce actions.")
		end
	end)
end)

RegisterServerEvent('esx_communityservice:sendToCommunityService')
AddEventHandler('esx_communityservice:sendToCommunityService', function(target, actions_count)

	local identifier = GetPlayerIdentifiers(target)[1]
	local xPlayer = ESX.GetPlayerFromId(source)
	local tPlayer = ESX.GetPlayerFromId(target)
	
	if not xPlayer or not tPlayer then
		return
	end

	if xPlayer.job.name == 'police' then
		if tPlayer.get('EscortBy') then
			yPlayer = ESX.GetPlayerFromId(tPlayer.get('EscortBy'))
			if yPlayer and yPlayer.get('EscortPlayer') and yPlayer.get('EscortPlayer') == target then
				yPlayer.set('EscortPlayer', nil)
				TriggerClientEvent('esx_policejob:dragCopOn', yPlayer.source, jailPlayer)
			end
			
			TriggerClientEvent('esx_policejob:dragOn', jailPlayer, yPlayer.source)
			tPlayer.set('EscortBy', nil)
		end
		
		if tPlayer.get('HandCuffedBy') then
			yPlayer = ESX.GetPlayerFromId(tPlayer.get('HandCuffedBy'))
			if yPlayer and yPlayer.get('HandCuffedPlayer') and yPlayer.get('HandCuffedPlayer') == target then
				if GetItemCount(yPlayer.source, 'handcuffs') == 0 then
					yPlayer.addInventoryItem('handcuffs', 1)
				end
				
				yPlayer.set('HandCuffedPlayer', nil)
			end
		end
		
		if tPlayer.get('HandCuff') then
			tPlayer.set('HandCuff', false)
			TriggerClientEvent('esx_policejob:handuncuffFast', target, true)
			tPlayer.set('HandCuffedBy', nil)
		end
	elseif xPlayer.getGroup() == 'user' then
		return
	end

	MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(result)
		if result[1] then
			MySQL.Async.execute('UPDATE communityservice SET actions_remaining = @actions_remaining WHERE identifier = @identifier', {
				['@identifier'] = identifier,
				['@actions_remaining'] = actions_count
			})
		else
			MySQL.Async.execute('INSERT INTO communityservice (identifier, actions_remaining) VALUES (@identifier, @actions_remaining)', {
				['@identifier'] = identifier,
				['@actions_remaining'] = actions_count
			})
		end
	end)
	
	for k,v in ipairs(tPlayer.loadout) do
		tPlayer.removeWeapon(v.name)
	end

	TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('comserv_msg', GetPlayerName(target), actions_count) }, color = { 147, 196, 109 } })
	TriggerClientEvent('esx_policejob:unrestrain', target)
	TriggerClientEvent('esx_communityservice:inCommunityService', target, actions_count)
end)

RegisterServerEvent('esx_communityservice:checkIfSentenced')
AddEventHandler('esx_communityservice:checkIfSentenced', function()
	local _source = source -- cannot parse source to client trigger for some weird reason
	local identifier = GetPlayerIdentifiers(_source)[1] -- get steam identifier

	MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(result)
		if result[1] ~= nil and result[1].actions_remaining > 0 then
			--TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('jailed_msg', GetPlayerName(_source), ESX.Math.Round(result[1].jail_time / 60)) }, color = { 147, 196, 109 } })
			TriggerClientEvent('esx_communityservice:inCommunityService', _source, tonumber(result[1].actions_remaining))
		end
	end)
end)

function releaseFromCommunityService(target)

	local identifier = GetPlayerIdentifiers(target)[1]
	MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(result)
		if result[1] then
			MySQL.Async.execute('DELETE from communityservice WHERE identifier = @identifier', {
				['@identifier'] = identifier
			})

			TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('comserv_finished', GetPlayerName(target)) }, color = { 147, 196, 109 } })
		end
	end)

	TriggerClientEvent('esx_communityservice:finishCommunityService', target)
end
