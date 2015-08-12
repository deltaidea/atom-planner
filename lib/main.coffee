{ Range } = require "atom"

allHeadersRegexp = /^.+\.planner$/g
taskRegexp = /^  \* (\d?\d:\d\d) (.*)$/i

module.exports = AtomPlanner =

	activate: ->
		console.log "Activating!"
		atom.workspace.observeTextEditors ( editor ) ->
			plannerRanges = []

			editor.onDidStopChanging ->
				console.log "Searching for planners:", editor.lastOpened

				editor.scan allHeadersRegexp, ( headerMatch ) ->

					headerStartPoint = headerMatch.range.start
					headerRow = headerStartPoint.row
					console.log "Found a planner header at line #{headerRow + 1}"

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
						if taskMatch

							task =
								time: taskMatch[ 1 ]
								text: taskMatch[ 2 ]

							planner.tasks.push task

							console.log "Found a planner task at line #{currentRow + 1}:", task

						else if ( currentRowText is "  " ) or
						( ( currentRowText is "" ) and isFirstLine )

							console.log "Adding a new task at line #{currentRow + 1}"

							newTaskText = "  * "

							editor.setTextInBufferRange currentRowRange, newTaskText,
								undo: "skip"

						else
							break

						currentRow += 1
						isFirstLine = no
