-- var is an empty table
var = {}

-- var is a table with one property
-- I would call this an associative array with one member, or a hashtable, or dictionary, etc.
var = { ["foo"] = "bar" }

-- var is a table with two properties, one of which has the value of an empty table
var = { ["foo"] = "bar", ["fruit"] = {} }

-- var is a table with two empty sub-tables
-- I would call this an array, since the members are un-named, and thus not strictly "properties" in my eyes
-- i.e. it's not an "associative" array
-- It's also a lot easier to say "an array of X members", rather than "a table of sub-tables with X members", but maybe that is in fact synonomous?
var = { {}, {} }

-- var is now mixing named and un-named members
-- Is this valid syntax?
-- To me this is nonsensical, as it is demonstrating characteristics of both associative and non-associative arrays
var = { ["foo"] = "bar", {} }

-- What about this?
-- Still mixing named and un-named members and the syntax seems problematic
var = ["foo"] = "bar", {}

-- What about this?
-- Syntax seems less problematic, and no longer mixing named and un-named members, but this can't be a table
-- In other languages this might be interpreted as an array
var = "foo", {}

-- What about this?
var = {}, {}

-- References:
-- https://www.lua.org/pil/11.html
-- https://www.lua.org/pil/2.5.html

-- So, it seems like the purpose of a table containing exclusively named properties (e.g. `var = { ["foo"] = "bar", ["fruit"] = {} }`) is to host data and represent an object, while the purpose of a table containing exclusively other un-named tables (e.g. `var = { {}, {} }`) is to be a bucket (potentially for data-hosting objects). Maybe I'm just biased from how I naturally use more familiar languages (e.g. PowerShell), but these use cases seem quite distinct to me. Are there hybrid use cases that I just can't wrap my head around right now?