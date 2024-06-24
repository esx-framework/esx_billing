function BillPlayerByIdentifier(targetIdentifier, senderIdentifier, sharedAccountName, label, amount)
	local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
	amount = ESX.Math.Round(amount)

	if amount > 0 then
		if string.match(sharedAccountName, "society_") then
			TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)
				if account then
					MySQL.insert('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)', {targetIdentifier, senderIdentifier, 'society', sharedAccountName, label, amount},
					function(rowsChanged)
						if not xTarget then
							return
						end

						xTarget.showNotification(TranslateCap('received_invoice'))
					end)
				else
					print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from invalid society - ^5%s^7"):format(senderIdentifier, sharedAccountName))
				end
			end)
		else
			MySQL.insert('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)', {targetIdentifier, senderIdentifier, 'player', senderIdentifier, label, amount},
			function(rowsChanged)
				if not xTarget then
					return
				end

				xTarget.showNotification(TranslateCap('received_invoice'))
			end)
		end
	end
end

function BillPlayer(targetId, senderIdentifier, sharedAccountName, label, amount)
	local xTarget = ESX.GetPlayerFromId(targetId)

	if not xTarget then
		return
	end

	BillPlayerByIdentifier(xTarget.identifier, senderIdentifier, sharedAccountName, label, amount)
end

RegisterNetEvent('esx_billing:sendBill', function(targetId, sharedAccountName, label, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local jobName = string.gsub(sharedAccountName, 'society_', '')

	if xPlayer.job.name ~= jobName then
		print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from a society (^5%s^7), but does not have the correct Job - Possibly Cheats"):format(xPlayer.source, sharedAccountName))
		return
	end

	BillPlayer(targetId, xPlayer.identifier, sharedAccountName, label, amount)
end)
exports("BillPlayer", BillPlayer)

RegisterNetEvent('esx_billing:sendBillToIdentifier', function(targetIdentifier, sharedAccountName, label, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local jobName = string.gsub(sharedAccountName, 'society_', '')

	if xPlayer.job.name ~= jobName then
		print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from a society (^5%s^7), but does not have the correct Job - Possibly Cheats"):format(xPlayer.source, sharedAccountName))
		return
	end

	BillPlayerByIdentifier(targetIdentifier, xPlayer.identifier, sharedAccountName, label, amount)
end)
exports("BillPlayerByIdentifier", BillPlayerByIdentifier)


ESX.RegisterServerCallback('esx_billing:getBills', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.query('SELECT amount, id, label FROM billing WHERE identifier = ?', {xPlayer.identifier},
	function(result)
		cb(result)
	end)
end)

ESX.RegisterServerCallback('esx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	if xPlayer then
		MySQL.query('SELECT amount, id, label FROM billing WHERE identifier = ?', {xPlayer.identifier},
		function(result)
			cb(result)
		end)
	else
		cb({})
	end
end)

ESX.RegisterServerCallback('esx_billing:payBill', function(source, cb, billId)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.single('SELECT sender, target_type, target, amount FROM billing WHERE id = ?', {billId},
	function(result)
		if result then
			local amount = result.amount
			local xTarget = ESX.GetPlayerFromIdentifier(result.sender)

			if result.target_type == 'player' then
				if xTarget then
					if xPlayer.getMoney() >= amount then
						MySQL.update('DELETE FROM billing WHERE id = ?', {billId},
						function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeMoney(amount, "Bill Paid")
								xTarget.addMoney(amount, "Paid bill")
								TriggerEvent("esx_billing:paidBill", source, billId)
								xPlayer.showNotification(TranslateCap('paid_invoice', ESX.Math.GroupDigits(amount)))
								xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
								cb(true)
							else
								cb()
							end
						end)
					elseif xPlayer.getAccount('bank').money >= amount then
						MySQL.update('DELETE FROM billing WHERE id = ?', {billId},
						function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeAccountMoney('bank', amount, "Bill Paid")
								xTarget.addAccountMoney('bank', amount, "Paid bill")
								TriggerEvent("esx_billing:paidBill", source, billId)
								xPlayer.showNotification(TranslateCap('paid_invoice', ESX.Math.GroupDigits(amount)))
								xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
								cb(true)
							else
								cb()
							end
						end)
					else
						xTarget.showNotification(TranslateCap('target_no_money'))
						xPlayer.showNotification(TranslateCap('no_money'))
						cb()
					end
				else
					xPlayer.showNotification(TranslateCap('player_not_online'))
					cb()
				end
			else
				TriggerEvent('esx_addonaccount:getSharedAccount', result.target, function(account)
					if xPlayer.getMoney() >= amount then
						MySQL.update('DELETE FROM billing WHERE id = ?', {billId},
						function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeMoney(amount, "Bill Paid")
								account.addMoney(amount)
								TriggerEvent("esx_billing:paidBill", source, billId)
								xPlayer.showNotification(TranslateCap('paid_invoice', ESX.Math.GroupDigits(amount)))
								if xTarget then
									xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
								end
								cb(true)
							else
								cb()
							end
						end)
					elseif xPlayer.getAccount('bank').money >= amount then
						MySQL.update('DELETE FROM billing WHERE id = ?', {billId},
						function(rowsChanged)
							if rowsChanged == 1 then
								xPlayer.removeAccountMoney('bank', amount, "Bill Paid")
								account.addMoney(amount)
								xPlayer.showNotification(TranslateCap('paid_invoice', ESX.Math.GroupDigits(amount)))
								TriggerEvent("esx_billing:paidBill", source, billId)
								if xTarget then
									xTarget.showNotification(TranslateCap('received_payment', ESX.Math.GroupDigits(amount)))
								end
								cb(true)
							else
								cb()
							end
						end)
					else
						if xTarget then
							xTarget.showNotification(TranslateCap('target_no_money'))
						end

						xPlayer.showNotification(TranslateCap('no_money'))
						cb()
					end
				end)
			end
		end
	end)
end)
