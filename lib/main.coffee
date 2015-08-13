{ Range } = require "atom"

# ["  * 21:02 foo 10 hours 30 minutes", "21", "02", "foo", " 10 hours", "10", " 30 minutes", "30"]
taskRegexp = /^  \* (\d\d):(\d\d) (.*?)( (\d{1,2}) hours?)?( (\d{1,2}) minutes?)?$/i

timeToText = ( time, readable = no ) ->
	if readable
		text = ""
		hours = time.getHours()
		minutes = time.getMinutes()
		if hours
			text += " #{hours} hour"
			if hours > 1
				text += "s"
		if minutes
			text += " #{minutes} minute"
			if minutes > 1
				text += "s"
		text
	else
		paddedHour = ( "00" + time.getHours() ).slice -2
		paddedMinute = ( "00" + time.getMinutes() ).slice -2
		"#{paddedHour}:#{paddedMinute}"

taskToText = ( task, returnAsParts = no ) ->
	parts =
		prefix: "  * "
		startTime: "#{timeToText task.startTime}"
		startTimeDelimiter: " "
		text: "#{task.text}"
		duration: ""

	if task.duration
		parts.duration = timeToText task.duration, yes

	if returnAsParts
		parts
	else
		parts.prefix + parts.startTime + parts.startTimeDelimiter + parts.text + parts.duration

getEndingTime = ( plannerOrTask ) ->
	if plannerOrTask.tasks
		task = plannerOrTask.tasks[ plannerOrTask.tasks.length - 1 ]
	else
		task = plannerOrTask
	timeZoneOffset = +new Date 1970, 0, 1
	new Date ( +task.startTime ) + ( +task.duration ) - timeZoneOffset

hourMinuteToTime = ( customHour, customMinute ) ->
	currentTime = new Date
	currentHour = currentTime.getHours()
	currentMinute = currentTime.getMinutes()
	new Date 1970, 0, 1, customHour ? currentHour, customMinute ? currentMinute

timeRemaining = ( task ) ->
	timeNow = hourMinuteToTime()
	endingTime = getEndingTime task
	timeZoneOffset = +new Date 1970, 0, 1
	new Date endingTime - timeNow + timeZoneOffset

createTask = ( planner, match = [], row ) ->
	parsedHour = match[ 1 ]
	parsedMinute = match[ 2 ]
	parsedText = match[ 3 ] ? ""
	parsedDurationHour = match[ 5 ] ? 0
	parsedDurationMinute = match[ 7 ] ? 0

	if planner?.tasks?.length
		startTime = getEndingTime planner
	else
		startTime = hourMinuteToTime parsedHour, parsedMinute

	startTime: startTime
	text: parsedText
	duration: new Date 1970, 0, 1, parsedDurationHour, parsedDurationMinute
	row: row
	editor: planner.editor
	planner: planner

isCurrentTask = ( task ) ->
	currentTime = hourMinuteToTime()
	startTime = task.startTime
	endingTime = getEndingTime task

	startTime <= currentTime < endingTime

getCurrentTask = ( planner ) ->
	for task in planner.tasks
		if isCurrentTask task
			return task
	return null

decorateTaskText = ( task ) ->
	parts = taskToText task, yes

	startPosition = parts.prefix.length +
		parts.startTime.length +
		parts.startTimeDelimiter.length

	endPosition = startPosition + parts.text.length

	partRange = new Range [ task.row, startPosition ], [ task.row, endPosition ]

	partMarker = task.editor.markBufferRange partRange,
		invalidate: "touch"
		persistent: no

	decoration = task.editor.decorateMarker partMarker,
		type: "highlight"
		class: "planner-task-text"

	task.editor.plannerMarkers.push partMarker

decoratePlannerHeader = ( planner ) ->
	headerMarker = planner.editor.markBufferPosition [ planner.headerRow, 0 ],
		invalidate: "touch"
		persistent: no

	decoration = planner.editor.decorateMarker headerMarker,
		type: "line"
		class: "planner-header"

	planner.editor.plannerMarkers.push headerMarker

cleanHighlight = ( planner ) ->
	for task in planner.tasks
		if task.highlightMarker
			task.highlightMarker.destroy()
			task.highlightMarker = null

highlightTask = ( task ) ->
	cleanHighlight task.planner

	marker = task.editor.markBufferPosition [ task.row, 0 ],
		invalidate: "touch"
		persistent: no

	decoration = task.editor.decorateMarker marker,
		type: "line"
		class: "planner-current-task"

	task.highlightMarker = marker
	task.editor.plannerMarkers.push marker

statusBarElement = document.createElement "span"
statusBarTile = null

updateStatusBar = ->
	editors = atom.workspace.getTextEditors()
	textList = []

	for editor in editors
		if not editor?.planners
			continue

		for planner in editor.planners
			if not planner.shouldAddToStatusBar
				continue

			task = getCurrentTask planner
			if task
				textList.push "#{task.text} - #{timeToText ( timeRemaining task ), yes}"

	statusBarElement.textContent = textList.join ", "

updateHighlightedTasks = ->
	editors = atom.workspace.getTextEditors()
	for editor in editors
		if not editor?.planners
			continue

		for planner in editor.planners
			task = getCurrentTask planner
			if task
				highlightTask task
			else
				cleanHighlight planner

setInterval updateStatusBar, 2000
setInterval updateHighlightedTasks, 2000

module.exports = AtomPlanner =

	activate: ->
		atom.workspace.observeTextEditors ( editor ) ->

			editor.plannerMarkers = []

			editor.onDidStopChanging ->

				editor.planners = []

				for oldMarker in editor.plannerMarkers
					oldMarker?.destroy?()
				editor.plannerMarkers = []

				currentRow = 0
				lastRowNumber = editor.getLastBufferRow()

				while currentRow <= lastRowNumber

					headerText = editor.lineTextForBufferRow currentRow

					if headerText.endsWith ".planner"
						isHeaderLine = yes
						shouldAddToStatusBar = yes
					else if headerText.endsWith ".planner-no-status"
						isHeaderLine = yes
						shouldAddToStatusBar = no

					if not isHeaderLine
						currentRow += 1
					else
						# For the next iteration.
						isHeaderLine = no

						if currentRow is lastRowNumber
							currentRowRange = new Range [ currentRow, 0 ],
								[ currentRow, headerText.length ]
							editor.setTextInBufferRange currentRowRange, headerText + "\n",
								undo: "skip"

						planner =
							editor: editor
							title: headerText
							headerRow: currentRow
							tasks: []
							shouldAddToStatusBar: shouldAddToStatusBar

						editor.planners.push planner

						decoratePlannerHeader planner

						currentRow += 1
						isFirstLine = yes

						loop
							try
								currentRowText = editor.lineTextForBufferRow currentRow

								currentRowRange = new Range [ currentRow, 0 ],
									[ currentRow, currentRowText.length ]

								taskMatch = currentRowText.match taskRegexp

								if taskMatch or
								( currentRowText is "  " ) or
								( ( currentRowText is "" ) and isFirstLine )

									task = createTask planner, taskMatch, currentRow
									planner.tasks.push task

									canonicalTaskText = taskToText task
									if canonicalTaskText isnt currentRowText
										editor.setTextInBufferRange currentRowRange, canonicalTaskText,
											undo: "skip"

									decorateTaskText task

									if task is getCurrentTask planner
										highlightTask task

								else
									break
							catch
								break

							currentRow += 1
							isFirstLine = no

				updateStatusBar()
				updateHighlightedTasks()

	consumeStatusBar: ( statusBar ) ->
		statusBarTile = statusBar?.addLeftTile
			item: statusBarElement
			priority: 10
