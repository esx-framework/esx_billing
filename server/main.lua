local function billPlayerByIdentifier(targetIdentifier, senderIdentifier, sharedAccountName, label, amount)
	local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
	amount = ESX.Math.Round(amount)

	if amount <= 0 then return end

	if string.match(sharedAccountName, "society_") then
		return TriggerEvent('esx_addonaccount:getSharedAccount', sharedAccountName, function(account)
			if not account then
				return print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from invalid society - ^5%s^7"):format(
					senderIdentifier, sharedAccountName))
			end

			MySQL.insert.await(
				'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)',
				{ targetIdentifier, senderIdentifier, 'society', sharedAccountName, label, amount })

			if not xTarget then return end

			xTarget.showNotification(TranslateCap('received_invoice'))
		end)
	end

	MySQL.insert.await(
		'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)',
		{ targetIdentifier, senderIdentifier, 'player', senderIdentifier, label, amount })

	if not xTarget then return end

	xTarget.showNotification(TranslateCap('received_invoice'))
end

local function billPlayer(targetId, senderIdentifier, sharedAccountName, label, amount)
	local xTarget = ESX.GetPlayerFromId(targetId)

	if not xTarget then return end

	billPlayerByIdentifier(xTarget.identifier, senderIdentifier, sharedAccountName, label, amount)
end

RegisterNetEvent('esx_billing:sendBill', function(targetId, sharedAccountName, label, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local jobName = string.gsub(sharedAccountName, 'society_', '')

	if xPlayer.job.name ~= jobName then
		return print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from a society (^5%s^7), but does not have the correct Job - Possibly Cheats")
			:format(xPlayer.source, sharedAccountName))
	end

	billPlayer(targetId, xPlayer.identifier, sharedAccountName, label, amount)
end)
exports("BillPlayer", billPlayer)

RegisterNetEvent('esx_billing:sendBillToIdentifier', function(targetIdentifier, sharedAccountName, label, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local jobName = string.gsub(sharedAccountName, 'society_', '')

	if xPlayer.job.name ~= jobName then
		return print(("[^2ERROR^7] Player ^5%s^7 Attempted to Send bill from a society (^5%s^7), but does not have the correct Job - Possibly Cheats")
			:format(xPlayer.source, sharedAccountName))
	end

	billPlayerByIdentifier(targetIdentifier, xPlayer.identifier, sharedAccountName, label, amount)
end)
exports("BillPlayerByIdentifier", billPlayerByIdentifier)

ESX.RegisterServerCallback('esx_billing:getBills', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	local result = MySQL.query.await('SELECT amount, id, label FROM billing WHERE identifier = ?', { xPlayer.identifier })
	cb(result)
end)

ESX.RegisterServerCallback('esx_billing:getTargetBills', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	if not xPlayer then return cb({}) end

	local result = MySQL.query.await('SELECT amount, id, label FROM billing WHERE identifier = ?', { xPlayer.identifier })
	cb(result)
end)

ESX.RegisterServerCallback('esx_billing:payBill', function(source, cb, billId)
	local xPlayer = ESX.GetPlayerFromId(source)

	local result = MySQL.single.await('SELECT sender, target_type, target, amount FROM billing WHERE id = ?', { billId })
	if not result then return end

	local amount = result.amount
	local xTarget = ESX.GetPlayerFromIdentifier(result.sender)

	if result.target_type == 'player' then
		if not xTarget then
			xPlayer.showNotification(TranslateCap('player_not_online'))
			return cb()
		end

		local paymentAccount = 'money'
		if xPlayer.getMoney() < amount then
			paymentAccount = 'bank'
			if xPlayer.getAccount('bank').money < amount then
				xTarget.showNotification(TranslateCap('target_no_money'))
				xPlayer.showNotification(TranslateCap('no_money'))
				return cb()
			end
		end

		local rowsChanged = MySQL.update.await('DELETE FROM billing WHERE id = ?', { billId })
		if rowsChanged ~= 1 then return cb() end

		xPlayer.removeAccountMoney(paymentAccount, amount, "Bill Paid")
		xTarget.addAccountMoney(paymentAccount, amount, "Paid bill")

		local groupedDigits = ESX.Math.GroupDigits(amount)
		xPlayer.showNotification(TranslateCap('paid_invoice', groupedDigits))
		xTarget.showNotification(TranslateCap('received_payment', groupedDigits))

		return cb(true)
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', result.target, function(account)
		local paymentAccount = 'money'
		if xPlayer.getMoney() < amount then
			paymentAccount = 'bank'
			if xPlayer.getAccount('bank').money < amount then
				xTarget.showNotification(TranslateCap('target_no_money'))
				xPlayer.showNotification(TranslateCap('no_money'))
				return cb()
			end
		end

		local rowsChanged = MySQL.update.await('DELETE FROM billing WHERE id = ?', { billId })
		if rowsChanged ~= 1 then return cb() end

		xPlayer.removeAccountMoney(paymentAccount, amount, "Bill Paid")
		account.addMoney(amount)

		TriggerEvent("esx_billing:paidBill", source, billId)

		local groupedDigits = ESX.Math.GroupDigits(amount)
		xPlayer.showNotification(TranslateCap('paid_invoice', groupedDigits))

		if xTarget then
			xTarget.showNotification(TranslateCap('received_payment', groupedDigits))
		end

		cb(true)
	end)
end)
