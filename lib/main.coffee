{ Range } = require "atom"

allHeadersRegexp = /^.+\.planner$/g

# ["  * 21:02 foo 10 hours 30 minutes", "21", "02", "foo", " 10 hours", "10", " 30 minutes", "30"]
taskRegexp = /^  \* (\d\d):(\d\d) (.*?)( (\d{1,2}) hours?)?( (\d{1,2}) minutes?)?$/i

timeToText = ( time ) ->
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
		if task.duration.getHours()
			parts.duration += " #{task.duration.getHours()} hours"
		if task.duration.getMinutes()
			parts.duration += " #{task.duration.getMinutes()} minutes"

	if returnAsParts
		parts
	else
		parts.prefix + parts.startTime + parts.startTimeDelimiter + parts.text + parts.duration

getEndingTime = ( planner ) ->
	lastTask = planner.tasks[ planner.tasks.length - 1 ]
	timeZoneOffset = +new Date 1970, 0, 1
	new Date ( +lastTask.startTime ) + ( +lastTask.duration ) - timeZoneOffset

hourMinuteToTime = ( customHour, customMinute ) ->
	currentTime = new Date
	currentHour = currentTime.getHours()
	currentMinute = currentTime.getMinutes()
	new Date 1970, 0, 1, customHour ? currentHour, customMinute ? currentMinute

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

module.exports = AtomPlanner =

	activate: ->
		atom.workspace.observeTextEditors ( editor ) ->

			decorationMarkers = []

			editor.onDidStopChanging ->

				for oldMarker in decorationMarkers
					oldMarker?.destroy?()
				decorationMarkers = []

				editor.scan allHeadersRegexp, ( headerMatch ) ->
					headerStartPoint = headerMatch.range.start
					headerRow = headerStartPoint.row

					planner =
						title: editor.lineTextForBufferRow headerRow
						tasks: []

					currentRow = headerRow + 1
					isFirstLine = yes
					loop
						currentRowText = editor.lineTextForBufferRow currentRow

						currentRowRange = new Range [ currentRow, 0 ],
							[ currentRow, currentRowText.length ]

						taskMatch = currentRowText.match taskRegexp

						if taskMatch or
						( currentRowText is "  " ) or
						( ( currentRowText is "" ) and isFirstLine )

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
