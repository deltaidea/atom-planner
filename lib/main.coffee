{ Range } = require "atom"

allHeadersRegexp = /^.+\.planner$/g
taskRegexp = /^  \* \d?\d:\d\d( [AP]M)? .*$/

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
					console.log "Found a planner header at line #{headerRow}"

					currentRow = headerRow + 1
					loop
						currentRowText = editor.lineTextForBufferRow currentRow

						currentRowRange = new Range [ currentRow, 0 ],
							[ currentRow, currentRowText.length ]

						if not taskRegexp.test currentRowText

							if ( currentRowText is "  " ) or
							( ( currentRowText is "" ) and ( currentRow is headerRow + 1 ) )

								editor.setTextInBufferRange currentRowRange, "  * ",
									undo: "skip"

							else
								break

						else
							console.log "Found a planner task at line #{currentRow}"

							taskMarker = editor.markBufferRange currentRowRange,
								persistent: no
								invalidate: "touch"

							editor.decorateMarker taskMarker,
								type: "highlight"
								class: "planner-task"

							currentRow += 1
