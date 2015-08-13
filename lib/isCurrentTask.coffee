getEndingTime = require "./getEndingTime"
hourMinuteToTime = require "./hourMinuteToTime"

module.exports = isCurrentTask = ( task ) ->
	currentTime = hourMinuteToTime()
	startTime = task.startTime
	endingTime = getEndingTime task

	startTime <= currentTime < endingTime
