{basename} = require "path"
{IconRule} = require "./icon-rule"
{directoryIcons, fileIcons} = require "./config"
{CompositeDisposable} = require "./utils"


class IconService
	useColour:   true
	showInTabs:  true
	changedOnly: false
	lightTheme:  false
	
	constructor: ->
		@fileCache      = {}
		@fileIcons      = @compile fileIcons
		@directoryIcons = @compile directoryIcons
		
		# Build scope-map with what grammars have already loaded
		@scopeMap = {}
		for name of atom.grammars.grammarsByScopeName
			@registerScope(name)
		
		# Monitor the global registry to add new grammars as they're loaded
		@disposables = new CompositeDisposable
		@disposables.add atom.grammars.onDidAddGrammar (grammar) =>
			@registerScope grammar.scopeName
		
		# Perform an early update of every directory icon to stop a FOUC
		@delayedRefresh(10)

	
	onWillDeactivate: ->
	
	
	# Return the CSS classes for a file's icon. Consumed by atom.file-icons service.
	# - path: Fully-qualified path of the file
	# - node: DOM element receiving the icon-class
	iconClassForPath: (path, node) ->
		filename  = basename path
		
		nodeClass = node?.classList
		isTab     = nodeClass?.contains("tab") and nodeClass?.contains("texteditor")
		
		# Don't show tab-icons unless the "Tab Pane Icon" setting is enabled
		return if !@showInTabs and isTab
		
		# Use cached matches for quicker lookup
		if cached = @fileCache[path]
			rule = @fileIcons[cached]
			ruleMatch = rule.matches path
		
		else for rule, index in @fileIcons
			ruleMatch = rule.matches filename
			if ruleMatch
				@fileCache[path] = index
				break
			else ruleMatch = null
		
		
		if ruleMatch?
			file    = node?.file
			suffix  = if rule.noSuffix then "" else "-icon"
			classes = if file?.symlink then ["icon-file-symlink-file"] else ["#{rule.icon}#{suffix}"]
			colour  = ruleMatch[1]
			auto    = ruleMatch[3]
			
			# Determine if colour should be used
			if colour && @useColour && (!@changedOnly || file?.status)
				
				# Bower needs special treatment to be visible
				if auto is "bower" then colour = (if @lightTheme then "medium-orange" else "medium-yellow")
				
				# This match is flagged as motif-sensitive: select colour based on theme brightness
				else if auto then colour = (if @lightTheme then "dark-" else "medium-") + colour
				
				classes.push(colour)
		
		# Return the array of classes
		classes || "icon-file-text"
	
	
	
	# Return the CSS classes for a directory's icon.
	#
	# Because Atom's file-icons service is limited to files only, we have to "synthesise"
	# our own icon-handling for directories. This method attempts to be analogous to the
	# one consumed by the icon service.
	iconClassForDirectory: (dir) ->
		return if dir.isRoot or dir.submodule or dir.symlink
		dirname = basename dir.path
		
		for rule in @directoryIcons
			ruleMatch = rule.matches dirname
			if ruleMatch then break
			else ruleMatch = null
		
		if ruleMatch?
			suffix = if rule.noSuffix then "" else "-icon"
			classes = ["#{rule.icon}#{suffix}"]
			if @useColour && colour = ruleMatch[1]
				classes.push(colour)
		classes
	
	
	
	# Update the icons of ALL currently-visible directories in the tree-view
	updateDirectoryIcons: ->
		for i in document.querySelectorAll(".tree-view .directory.entry")
			@setDirectoryIcon(i.directory, i)
	
	
	# Set the icon of a single directory
	setDirectoryIcon: (dir, el) ->
		className = @iconClassForDirectory(dir)
		if className
			if Array.isArray(className) then className = className.join(" ")
			el.directoryName.className = "name icon " + className
	
	
	# Parse a dictionary of file-matching patterns loaded from icon-config
	compile: (rules) ->
		results = for name, attr of rules
			new IconRule name, attr
		
		results.sort IconRule.sort
	
	
	# Locate an IconRule that matches a TextMate scope, storing a connection if found
	registerScope: (name) ->
		for rule in @fileIcons when rule.scopes?
			for index, pattern of rule.scopes when pattern.test(name)
				return @scopeMap[name] = {rule, matchIndex: index}
	
	
	
	# Force a complete refresh of the icon display.
	# Intended to be called when a package setting's been modified.
	refresh: () ->
		
		# Update the icon classes of a specific file-entry
		updateIcon = (label, baseClass) =>
			label.className = baseClass
			iconClass = @iconClassForPath(label.dataset.path, label.parentElement)
			if iconClass
				unless Array.isArray iconClass
					iconClass = iconClass.toString().split(/\s+/g)
				label.classList.add iconClass...
		
		ws = atom.views.getView(atom.workspace)
		for file in ws.querySelectorAll ".file > .name[data-path]"
			updateIcon file, "name icon"
		
		for tab in ws.querySelectorAll ".tab > .title[data-path]"
			updateIcon tab, "title icon"
		
		@updateDirectoryIcons()
	
	
	# Queue a delayed refresh. Repeated calls to this method do nothing:
	# only one refresh will be fired after a specified delay has elapsed.
	# - delay: Amount of time to wait, expressed in milliseconds
	delayedRefresh: (delay) ->
		clearTimeout @timeoutID
		@timeoutID = setTimeout (=> @refresh()), delay
		

module.exports = IconService
