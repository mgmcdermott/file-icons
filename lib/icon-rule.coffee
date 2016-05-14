{isRegExp, escapeRegExp} = require "./utils"


# Represents a named icon-matching rule defined by icon-config
class IconRule
	
	constructor: (name, args) ->
		@name = name
		{@match, @icon, @colour, @priority, @noSuffix} = args
		@priority ?= 1
		
		# Store the name in lowercase for quicker sorting
		@nameLowercased = name.toLowerCase()
		
		# Make sure we're always dealing with an array
		unless Array.isArray @match
			@match = [[@match, @colour]]
		
		# Refine each match definition
		match = for i, value of @match
			[pattern, colour] = value
			
			# Convert string-based patterns into actual regex
			unless isRegExp pattern
				source = escapeRegExp(pattern)+"$"
				value[0] = new RegExp source, "i"
			
			# Flag that bloody Bower-bird which needs special treatment
			if /^bower$/i.test colour
				value[2] = "bower"
			
			# Flag colours which need adjustment depending on theme's brightness
			else if auto = colour?.match /^auto-(.+)$/i
				value[1] = auto[1]
				value[2] = true
			
			value
			
		
	
	matches: (path) ->
		for i in @match
			if i[0].test path then return i
		false
	
	
	# Static sorting method, passed to Array.prototype.sort
	@sort: (a, b) ->
		
		# Sort by priority first
		if a.priority > b.priority then return -1
		if a.priority < b.priority then return  1
		
		# Then sort by name
		if a.nameLowercased < b.nameLowercased then return -1
		if a.nameLowercased > b.nameLowercased then return 1
		return 0


module.exports = {IconRule}
