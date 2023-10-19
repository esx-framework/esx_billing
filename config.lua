Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

Config.EnableAutoPay = false -- Enables or disables automatic payments for emergency services issued bills (default is false).

Config.AutoPaySocieties = { -- Societies that can auto-bill players when invoices are issued. Police and EMS are true by default.
	['society_police'] = true,
	['society_ambulance'] = true
}