NMS_MOD_DEFINITION_CONTAINER = {
	["MOD_FILENAME"] = "Template Mod.pak", 
	["MOD_AUTHOR"] = "Mod Author",
	["LUA_AUTHOR"] = "Lua Author",
	--["MOD_MAINTENANCE"] = "Maintainer",
	["NMS_VERSION"] = "4.70",
	["MOD_DESCRIPTION"] = "Description of mod",
	["MODIFICATIONS"] = {
		-- The value of MODIFICATIONS must be a table containing 1 or more sub-tables
		{
			["MBIN_CHANGE_TABLE"] = { 
				{
					["MBIN_FILE_SOURCE"] 	= "GCUIGLOBALS.GLOBAL.MBIN",
					["EXML_CHANGE_TABLE"] 	= 
					{
						{
							["PRECEDING_KEY_WORDS"] = {"ModelViews","ModelViews","Suit"},
							["VALUE_CHANGE_TABLE"] 	= 
							{
								{"LightPitch",	"60"},
								{"LightRotate",	"0"},
							}	
						},
						{
							["PRECEDING_KEY_WORDS"] = {"ModelViews","ModelViews","Weapon"},
							["INTEGER_TO_FLOAT"] 	= "FORCE",
							["VALUE_CHANGE_TABLE"] 	= 
							{
								{"Distance",	"2.8"},
								{"x",	"-0.5"},
								{"y",	"0.02"},
								{"LightPitch",	"30"},
								{"LightRotate",	"-30"},
								{"FocusType",	"ResourceBoundingHeight"},
							}	
						}
					}
				}
			}
		}
	}	
}