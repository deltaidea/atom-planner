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

timeLeft = ( task ) ->
	timeNow = hourMinuteToTime()
	endingTime = getEndingTime task
	timeZoneOffset = +new Date 1970, 0, 1
	new Date endingTime - timeNow + timeZoneOffset

createTask = ( planner, match = [] ) ->
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

isCurrentTask = ( task ) ->
	currentTime = hourMinuteToTime()
	startTime = task.startTime
	endingTime = getEndingTime task

	startTime <= currentTime < endingTime

getCurrentTask = ( planner ) ->
	for task in planner.tasks
		if isCurrentTask task
			return task

decorateTaskText = ( editor, currentRow, parts ) ->
	startPosition = parts.prefix.length +
		parts.startTime.length +
		parts.startTimeDelimiter.length

	endPosition = startPosition + parts.text.length

	partRange = new Range [ currentRow, startPosition ], [ currentRow, endPosition ]

	partMarker = editor.markBufferRange partRange,
		invalidate: "touch"
		persistent: no

	decoration = editor.decorateMarker partMarker,
		type: "highlight"
		class: "planner-task-text"

	partMarker

decoratePlannerHeader = ( editor, currentRow ) ->
	headerMarker = editor.markBufferPosition [ currentRow, 0 ],
		invalidate: "touch"
		persistent: no

	decoration = editor.decorateMarker headerMarker,
		type: "line"
		class: "planner-header"

	headerMarker

statusBarElement = document.createElement "span"
statusBarTile = null
statusBarPlanners = []

updateStatusBar = ->
	textList = []

	for planner in statusBarPlanners
		task = getCurrentTask planner
		if task
			textList.push "#{task.text} - #{timeToText ( timeLeft task ), yes}"

	statusBarElement.textContent = textList.join ", "

addPlannerToStatusBar = ( planner ) ->
	statusBarPlanners.push planner
	updateStatusBar()

resetStatusBar = ->
	statusBarPlanners = []
	updateStatusBar()

setInterval updateStatusBar, 2000

module.exports = AtomPlanner =

	activate: ->
		atom.workspace.observeTextEditors ( editor ) ->

			decorationMarkers = []

			editor.onDidStopChanging ->

				resetStatusBar()

				for oldMarker in decorationMarkers
					oldMarker?.destroy?()
				decorationMarkers = []

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
						isHeaderLine = no

						planner =
							title: headerText
							tasks: []

						decorationMarkers.push decoratePlannerHeader editor, currentRow

						currentRow += 1
						isFirstLine = yes

						console.log "============"

						loop
							currentRowText = editor.lineTextForBufferRow currentRow

							currentRowRange = new Range [ currentRow, 0 ],
								[ currentRow, currentRowText.length ]

							taskMatch = currentRowText.match taskRegexp

							if taskMatch or
							( currentRowText is "  " ) or
							( ( currentRowText is "" ) and isFirstLine )

								console.log "line #{currentRow}: text is #{currentRowText}"

								task = createTask planner, taskMatch
								planner.tasks.push task

								canonicalTaskText = taskToText task
								if canonicalTaskText isnt currentRowText
									editor.setTextInBufferRange currentRowRange, canonicalTaskText,
										undo: "skip"

								parts = taskToText task, yes

								decorationMarkers.push decorateTaskText editor, currentRow, parts

							else
								break

							currentRow += 1
							isFirstLine = no

						if planner.tasks.length and shouldAddToStatusBar
							addPlannerToStatusBar planner

	consumeStatusBar: ( statusBar ) ->
		statusBarTile = statusBar?.addLeftTile
			item: statusBarElement
			priority: 10
