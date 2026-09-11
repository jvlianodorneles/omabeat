.pragma library

// BeatModel.js — Core Swatch Internet Time (.beat) calculations and formatting
//
// Reference:
// • Biel Mean Time (BMT) = UTC + 1 hour (Central European Time without DST).
// • 1 solar day = 1000 .beats = 86,400 seconds = 86,400,000 milliseconds.
// • 1 .beat = 86.4 seconds = 86,400 milliseconds.
// • 1 centibeat = 0.864 seconds = 864 milliseconds.
// • Midnight in Biel (00:00:00 BMT) = @000 .beats.
// • Noon in Biel (12:00:00 BMT) = @500 .beats.

function pad2(n) {
  var s = String(n || 0)
  while (s.length < 2) s = "0" + s
  return s
}

function pad3(n) {
  var s = String(n || 0)
  while (s.length < 3) s = "0" + s
  return s
}

// Calculate complete Swatch Internet Time stats for a given Date
function calculateBeats(date) {
  date = date || new Date()

  // Extract UTC time components
  var utcHours = date.getUTCHours()
  var utcMinutes = date.getUTCMinutes()
  var utcSeconds = date.getUTCSeconds()
  var utcMillis = date.getUTCMilliseconds()

  // Total milliseconds elapsed in current UTC day
  var utcMs = (utcHours * 3600 + utcMinutes * 60 + utcSeconds) * 1000 + utcMillis

  // BMT is permanently UTC + 1 hour (+3,600,000 ms) with no Daylight Saving Time
  var bmtMs = (utcMs + 3600000) % 86400000
  if (bmtMs < 0) bmtMs += 86400000

  // Total beats (float from 0.0 to 999.999...)
  var totalBeats = bmtMs / 86400.0
  var intBeats = Math.floor(totalBeats)
  if (intBeats >= 1000) intBeats = 0

  var centibeats = Math.floor((totalBeats - intBeats) * 100)
  if (centibeats >= 100) centibeats = 99

  // Day progress ratio and percentage
  var progress = Math.max(0.0, Math.min(1.0, totalBeats / 1000.0))
  var progressPercent = Number((progress * 100).toFixed(1))

  // BMT date and time
  var bmtDateObj = new Date(date.getTime() + 3600000)
  var bmtYear = bmtDateObj.getUTCFullYear()
  var bmtMonth = bmtDateObj.getUTCMonth() + 1
  var bmtDay = bmtDateObj.getUTCDate()
  var bmtDateStr = bmtYear + "-" + pad2(bmtMonth) + "-" + pad2(bmtDay)
  var bmtTimeStr = pad2(bmtDateObj.getUTCHours()) + ":" + pad2(bmtDateObj.getUTCMinutes()) + ":" + pad2(bmtDateObj.getUTCSeconds())

  // Swatch Internet Date format: @dDD.MM.YY
  var yy = String(bmtYear).slice(-2)
  var internetDateStr = "@d" + pad2(bmtDay) + "." + pad2(bmtMonth) + "." + yy

  // UTC time
  var utcTimeStr = pad2(utcHours) + ":" + pad2(utcMinutes) + ":" + pad2(utcSeconds)

  // Local time
  var localTimeStr = pad2(date.getHours()) + ":" + pad2(date.getMinutes()) + ":" + pad2(date.getSeconds())
  var localShortTimeStr = pad2(date.getHours()) + ":" + pad2(date.getMinutes())
  var localDateStr = date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())

  var beatsRemaining = 1000 - intBeats

  return {
    beats: totalBeats,
    intBeats: intBeats,
    centibeats: centibeats,
    formattedInt: "@" + pad3(intBeats),
    formattedCentibeats: "@" + pad3(intBeats) + "." + pad2(centibeats),
    digitsOnly: pad3(intBeats),
    centibeatsDigits: pad2(centibeats),
    progress: progress,
    progressPercent: progressPercent,
    bmtTime: bmtTimeStr,
    bmtDate: bmtDateStr,
    internetDate: internetDateStr,
    utcTime: utcTimeStr,
    localTime: localTimeStr,
    localShortTime: localShortTimeStr,
    localDate: localDateStr,
    beatsRemaining: beatsRemaining
  }
}

// Convert a Swatch Beat value (0 - 1000) to Local Time
function beatsToLocalTime(beatVal, baseDate) {
  baseDate = baseDate || new Date()
  beatVal = Math.max(0, Math.min(1000, Number(beatVal) || 0))

  // Find start of BMT day in UTC epoch milliseconds
  var bmtDate = new Date(baseDate.getTime() + 3600000)
  var bmtYear = bmtDate.getUTCFullYear()
  var bmtMonth = bmtDate.getUTCMonth()
  var bmtDay = bmtDate.getUTCDate()

  var bmtMidnightUtcMs = Date.UTC(bmtYear, bmtMonth, bmtDay, 0, 0, 0) - 3600000
  var targetUtcMs = bmtMidnightUtcMs + Math.round(beatVal * 86400)
  var localDate = new Date(targetUtcMs)

  var localHours = localDate.getHours()
  var localMinutes = localDate.getMinutes()
  var localSeconds = localDate.getSeconds()

  return {
    date: localDate,
    timeStr: pad2(localHours) + ":" + pad2(localMinutes) + ":" + pad2(localSeconds),
    shortTimeStr: pad2(localHours) + ":" + pad2(localMinutes),
    hours: localHours,
    minutes: localMinutes,
    seconds: localSeconds
  }
}

// Convert Local Time (hours, minutes, seconds) to Swatch Internet Time
function localTimeToBeat(hours, minutes, seconds, baseDate) {
  baseDate = baseDate || new Date()
  hours = Math.max(0, Math.min(23, Number(hours) || 0))
  minutes = Math.max(0, Math.min(59, Number(minutes) || 0))
  seconds = Math.max(0, Math.min(59, Number(seconds) || 0))

  var localDt = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), hours, minutes, seconds, 0)
  return calculateBeats(localDt)
}

// Key Swatch Milestones and their corresponding local times
function getMilestones(currentBeat, baseDate) {
  baseDate = baseDate || new Date()
  var rawBeats = [
    { beat: 0, title: "Midnight BMT", icon: "\uf186", desc: "Start of Internet Day (00:00 Biel / 23:00 UTC)" },
    { beat: 250, title: "Morning BMT", icon: "\uf185", desc: "First Quadrant (06:00 Biel / 05:00 UTC)" },
    { beat: 500, title: "Noon BMT", icon: "\uf005", desc: "Solar Noon in Biel (12:00 Biel / 11:00 UTC)" },
    { beat: 750, title: "Evening BMT", icon: "\uf0ac", desc: "Third Quadrant (18:00 Biel / 17:00 UTC)" }
  ]

  var result = []
  for (var i = 0; i < rawBeats.length; i++) {
    var item = rawBeats[i]
    var conv = beatsToLocalTime(item.beat, baseDate)
    var diff = Math.abs(currentBeat - item.beat)
    var isCurrent = (diff <= 62.5) || (item.beat === 0 && currentBeat >= 937.5)

    result.push({
      beat: item.beat,
      formattedBeat: "@" + pad3(item.beat),
      title: item.title,
      icon: item.icon,
      desc: item.desc,
      localTime: conv.shortTimeStr,
      isCurrent: isCurrent
    })
  }
  return result
}

// Next Century Beat info (@100, @200, etc.)
function getNextCenturyBeat(currentBeat) {
  var intB = Math.floor(currentBeat)
  var nextVal = (Math.floor(intB / 100) + 1) * 100
  if (nextVal >= 1000) nextVal = 0

  var beatsLeft = nextVal > intB ? (nextVal - intB) : (1000 - intB + nextVal)
  var minutesLeft = Math.round(beatsLeft * 86.4 / 60)

  return {
    nextBeat: nextVal,
    formattedNextBeat: "@" + pad3(nextVal),
    beatsLeft: beatsLeft,
    minutesLeft: minutesLeft
  }
}

// Format the display string for the status bar
function formatDisplay(info, format, showCentibeats, showPrefix, showSuffix) {
  if (!info) return "@000"

  var prefix = showPrefix ? "@" : ""
  var suffix = showSuffix ? " .beats" : ""

  var mainNumber = showCentibeats
    ? (info.digitsOnly + "." + info.centibeatsDigits)
    : info.digitsOnly

  switch (format) {
    case "dot_beat":
      return "." + mainNumber + suffix
    case "centibeats":
      return prefix + info.digitsOnly + "." + info.centibeatsDigits + suffix
    case "with_unit":
      return prefix + mainNumber + " .beats"
    case "percentage":
      return prefix + mainNumber + " (" + info.progressPercent + "%)"
    case "dual_local":
      return prefix + mainNumber + " (" + info.localShortTime + ")"
    case "beats":
    default:
      return prefix + mainNumber + suffix
  }
}

// Next format in rotation when clicking / cycling
function nextFormat(current) {
  var formats = ["beats", "centibeats", "dot_beat", "with_unit", "percentage", "dual_local"]
  var idx = formats.indexOf(current)
  if (idx === -1) return "beats"
  return formats[(idx + 1) % formats.length]
}
