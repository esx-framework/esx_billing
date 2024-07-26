local isDead = false

local function showBillsMenu()
	ESX.TriggerServerCallback('esx_billing:getBills', function(bills)
		if #bills <= 0 then return ESX.ShowNotification(TranslateCap('no_invoices')) end

		local elements = {
			{ unselectable = true, icon = 'fas fa-scroll', title = TranslateCap('invoices') }
		}

		for _, v in ipairs(bills) do
			elements[#elements + 1] = {
				icon = 'fas fa-scroll',
				title = ('%s - <span style="color:red;">%s</span>'):format(v.label,
					TranslateCap('invoices_item', ESX.Math.GroupDigits(v.amount))),
				billId = v.id
			}
		end

		ESX.OpenContext('right', elements, function(menu, element)
			local billId = element.billId

			ESX.TriggerServerCallback('esx_billing:payBill', function(resp)
				showBillsMenu()

				if not resp then return end
				TriggerEvent('esx_billing:paidBill', billId)
			end, billId)
		end)
	end)
end

RegisterCommand('showbills', function()
	if not isDead then
		showBillsMenu()
	end
end, false)

RegisterKeyMapping('showbills', TranslateCap('keymap_showbills'), 'keyboard', 'F7')

AddEventHandler('esx:onPlayerDeath', function() isDead = true end)
AddEventHandler('esx:onPlayerSpawn', function() isDead = false end)
