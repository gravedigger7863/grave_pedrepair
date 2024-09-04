Config = {}

Config.pedModel = "mp_m_waremech_01" 
Config.Animation = "WORLD_HUMAN_WELDING" 
Config.PedName = "Jeremy the mechanic" -- Default message ingame
Config.PedSubject = "Repair"
Config.PedMessage = "Your vehicle has been repaired. Be careful next time!"
Config.PedPicture = "CHAR_MP_MECHANIC"
Config.WalkTime = 5000
Config.PedAnimationTime = 8000

-------------------------------------Job and Money-------------------------------------
Config.LSRequired = 1
Config.LSJobName = "mechanic"
Config.Society = "society_mechanic"
Config.SharedAccount = true
Config.Money = 1500
Config.RequireMechanicOnline = false  -- Set to true if you prefer requiring mechanics to be online for the repair to work

-------------------------------------Translation-------------------------------------
Strings = {
    HelpNotification = "Press ~INPUT_CONTEXT~ to repair your vehicle",
    OnFoot           = "Get into your vehicle to do this",
    NoMoney          = "You don't have enough money you need " .. Config.Money .. " to do this",
    GetIn            = "Get into your vehicle to do this",
    MechanicsonDuty  = "There are mechanics on duty"
}

-------------------------------------Don't touch :)-------------------------------------
Config.UsingESXLegacy = false -- Just leave it as is
Config.RepairShops = {}  -- This will hold the repair shop data dynamically
