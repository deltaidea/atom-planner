{ Range } = require "atom"

allHeadersRegexp = /^.+\.planner$/g
taskRegexp = /^  \* \d?\d:\d\d( [AP]M)? .*$/

module.exports = AtomPlanner =

	activate: ->
		console.log "Activating!"
		atom.workspace.observeTextEditors ( editor ) ->
			plannerRanges = []

			editor.onDidChange ->
				console.log "Searching for planners:", editor.lastOpened

				editor.scan allHeadersRegexp, ( match ) ->

					headerMarker = editor.markBufferRange match.range,
						persistent: no
						invalidate: "touch"

					editor.decorateMarker headerMarker,
						type: "highlight"
						class: "planner-header"

					headerLine = match.range.start.row
					console.log "Found a planner header at line #{headerLine}"

					currentLine = headerLine + 1
					loop
						currentLineText = editor.lineTextForBufferRow currentLine

						currentLineRange = new Range [ currentLine, 0 ],
							[ currentLine, currentLineText.length ]

						if not taskRegexp.test currentLineText

							if ( currentLineText is "  " ) or
							( ( currentLineText is "" ) and ( currentLine is headerLine + 1 ) )

								editor.setTextInBufferRange currentLineRange, "  * ",
									undo: "skip"

							else
								break

						else
							console.log "Found a planner task at line #{currentLine}"

							taskMarker = editor.markBufferRange currentLineRange,
								persistent: no
								invalidate: "touch"

							editor.decorateMarker taskMarker,
								type: "highlight"
								class: "planner-task"

							currentLine += 1
