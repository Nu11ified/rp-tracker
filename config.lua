Config = {}

-- Cooldown time in seconds (4 hours = 14400 seconds)
Config.CooldownTime = 14400

-- Enable two-region mode. If true, up to 2 RPs can run simultaneously, else only 1.
Config.TwoRegionEnabled = true
Config.MaxActiveRPs = Config.TwoRegionEnabled and 2 or 1

-- Ace permission required to manage the queue
Config.ManageQueueAce = "rp.queue.manage"

-- Allowed Regions
Config.AllowedRegions = {
    "Paleto",
    "Sandy",
    "City",
    "Grapeseed",
    "Vinewood",
    "MirrorPark"
}

-- Maximum length for title and description to prevent abuse
Config.MaxTitleLength = 50
Config.MaxDescriptionLength = 200

-- Data file for persistent storage
Config.DataFile = "rp_data.json"
