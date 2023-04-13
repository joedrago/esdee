filenameElem = null
canS = canM = canD = ctxS = ctxM = ctxD = null
DEFAULT_RADIUS = 20
maskRadius = DEFAULT_RADIUS
maskDrawing = false
maskTouchID = null
maskScale = 1
maskUndo = []
maskLastX = null
maskLastY = null
workingScale = 1

qs = (name) ->
  url = window.location.href
  name = name.replace(/[\[\]]/g, '\\$&')
  regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)')
  results = regex.exec(url);
  if not results or not results[2]
    return null
  return decodeURIComponent(results[2].replace(/\+/g, ' '))

maskScaleOverride = qs('scale')
if not maskScaleOverride?
  maskScaleOverride = qs('s')
if maskScaleOverride?
  maskScale = Math.max(1, Math.min(parseInt(maskScaleOverride), 4))

preventDefaults = (e) ->
  e.preventDefault()
  e.stopPropagation()

window.undoPush = ->
  maskUndo.push(canM.toDataURL('image/png'))

window.undoPop = ->
  if maskUndo.length > 0
    prevState = maskUndo.pop()
    prevImage = new Image()
    prevImage.onload = ->
      console.log "prevImage.onload() #{prevImage.width}x#{prevImage.height}"
      ctxM.fillStyle = "#000"
      ctxM.fillRect(0, 0, canM.width, canM.height)
      ctxM.drawImage(prevImage, 0, 0)
      updateDraw()
    prevImage.src = prevState

window.invert = ->
  backup = canM.toDataURL('image/png')
  backupImage = new Image()
  backupImage.onload = ->
    console.log "backupImage.onload() #{backupImage.width}x#{backupImage.height}"
    ctxM.fillStyle = "#000"
    ctxM.fillRect(0, 0, canM.width, canM.height)
    ctxM.filter = 'invert(1)'
    ctxM.drawImage(backupImage, 0, 0)
    ctxM.filter = 'none'
    updateDraw()
  backupImage.src = backup

window.updateDraw = ->
  ctxD.drawImage(canS, 0, 0)
  ctxD.globalCompositeOperation = 'screen'
  ctxD.drawImage(canM, 0, 0)
  ctxD.globalCompositeOperation = 'source-over'
  if maskLastX? and maskLastY?
    drawCursor(maskLastX, maskLastY)

window.drawMaskCircle = (x, y) ->
  ctxM.beginPath()
  ctxM.arc(x, y, maskRadius, 0, 2 * Math.PI, false)
  ctxM.fillStyle = '#fff'
  ctxM.fill()

window.drawCursor = (x, y) ->
  ctxD.beginPath()
  ctxD.arc(x, y, maskRadius, 0, 2 * Math.PI, false)
  ctxD.fillStyle = '#070'
  ctxD.fill()

window.beginDrawing = (x, y) ->
  # console.log "beginDrawing #{x}, #{y}"
  undoPush()
  drawMaskCircle(x * workingScale, y * workingScale)
  updateDraw()
  maskDrawing = true
window.onMouseMove = (x, y) ->
  # console.log "onMouseMove #{x}, #{y}"
  maskLastX = x * workingScale
  maskLastY = y * workingScale
  if maskDrawing
    drawMaskCircle(maskLastX, maskLastY)
  updateDraw()
window.endDrawing = ->
  # console.log "endDrawing"
  maskDrawing = false
  updateDraw()

window.copyImageToClipboard = (blob) ->
  try
    navigator.clipboard.write [
      new ClipboardItem {
        'image/png': blob
      }
    ]
  catch e
    console.error(e)

window.buildUI = (srcImage) ->
  srcW = srcImage.width
  srcH = srcImage.height
  srcAspect = srcW / srcH

  if srcAspect < 1
    dstH = 512 * maskScale
    dstW = dstH * srcAspect
  else
    dstW = 512 * maskScale
    dstH = dstW / srcAspect

  dstW = Math.floor(dstW / 4) * 4
  dstH = Math.floor(dstH / 4) * 4

  windowAspect = window.innerWidth / window.innerHeight
  console.log "windowAspect: #{windowAspect}"
  if windowAspect < 1
    workingW = window.innerWidth - 20
    workingH = workingW / srcAspect
  else
    workingH = window.innerHeight - 150
    if workingH < 200
      workingH = 200
    workingW = workingH * srcAspect
  workingW = Math.floor(workingW)
  workingH = Math.floor(workingH)
  workingScale = dstW / workingW
  document.getElementById('overall').style.width = workingW + 4

  console.log "dstW #{dstW}, dstH #{dstH}, workingW #{workingW}, workingH #{workingH}"

  html = """
    <canvas id="canvasS" width="#{dstW}" height="#{dstH}"></canvas>
    <canvas id="canvasM" width="#{dstW}" height="#{dstH}"></canvas>
    <canvas id="canvasD" width="#{dstW}" height="#{dstH}"></canvas>
    <div id="dims"></div>
  """
  document.getElementById('work').innerHTML = html

  canS = document.getElementById('canvasS')
  canM = document.getElementById('canvasM')
  canD = document.getElementById('canvasD')
  ctxS = canS.getContext('2d')
  ctxM = canM.getContext('2d')
  ctxD = canD.getContext('2d')
  for c in [canS, canM, canD]
    c.style.width = "#{workingW}px"
    c.style.height = "#{workingH}px"

  document.getElementById('dims').innerHTML = "#{dstW}x#{dstH}"

  # Scale source image to source canvas
  ctxS.drawImage(srcImage, 0, 0, dstW, dstH)

  # Create empty mask
  ctxM.fillStyle = "#000"
  ctxM.fillRect(0, 0, canM.width, canM.height)
  maskUndo = []
  maskRadius = DEFAULT_RADIUS * maskScale
  maskDrawing = false
  maskLastX = null
  maskLastY = null
  maskTouchID = null

  # update draw canvas
  updateDraw()

  # hookup listeners
  canvasD.addEventListener 'mousedown', (ev) ->
    r = canD.getBoundingClientRect()
    beginDrawing(ev.pageX - r.left, ev.pageY - r.top)
  canvasD.addEventListener 'mousemove', (ev) ->
    r = canD.getBoundingClientRect()
    onMouseMove(ev.pageX - r.left, ev.pageY - r.top)
  canvasD.addEventListener 'mouseup', (ev) ->
    endDrawing()
  canvasD.addEventListener 'mouseleave', (ev) ->
    maskLastX = null
    maskLastY = null
    endDrawing()

  canvasD.addEventListener 'touchstart', (ev) ->
    if ev.touches.length > 1
      return
    # ev.preventDefault()
    if not maskDrawing and (ev.touches.length == 1)
      touch = ev.touches[0]
      maskTouchID = touch.identifier
      r = canD.getBoundingClientRect()
      beginDrawing(touch.pageX - r.left, touch.pageY - r.top)
  canvasD.addEventListener 'touchmove', (ev) ->
    if ev.touches.length > 1
      return
    ev.preventDefault()
    for touch in ev.changedTouches
      if touch.identifier == maskTouchID
        r = canD.getBoundingClientRect()
        onMouseMove(touch.pageX - r.left, touch.pageY - r.top)
  canvasD.addEventListener 'touchend', (ev) ->
    # ev.preventDefault()
    if ev.touches.length == 0
      maskTouchID = null
      maskLastX = null
      maskLastY = null
      endDrawing()

  # Create/display buttons
  html = """
    <div class="button" id="invert">Inv</div>
    <div class="button" id="undo">Undo</div>
    <input type="range" id="radius" name="" min="1" max="#{50 * maskScale}" value="#{DEFAULT_RADIUS * maskScale}">
    <div class="button" id="copys">Copy Image</div>
    <div class="button" id="copym">Copy Mask</div>
  """
  document.getElementById('buttons').innerHTML = html
  document.getElementById('undo').addEventListener 'click', (ev) ->
    undoPop()
  document.getElementById('invert').addEventListener 'click', (ev) ->
    invert()
  document.getElementById('copys').addEventListener 'click', (ev) ->
    canS.toBlob (blob) ->
      copyImageToClipboard(blob)
    , 'image/png'
  document.getElementById('copym').addEventListener 'click', (ev) ->
    canM.toBlob (blob) ->
      copyImageToClipboard(blob)
    , 'image/png'
  document.getElementById('radius').addEventListener 'change', (ev) ->
    maskRadius = ev.target.value
    updateDraw()

window.initImage = (name, where, content) ->
  if where == 'file'
    filenameElem.innerHTML = name
  else
    filenameElem.innerHTML = where
  img = document.createElement('img')
  img.onload = ->
    buildUI(img)
  img.src = content

window.handleFiles = (files, where) ->
  for file in files
    # console.log file
    reader = new FileReader()
    reader.onloadend = ->
      initImage(file.name, where, reader.result)
    reader.readAsDataURL(file)


window.handleDrop = (e) ->
  dt = e.dataTransfer
  files = dt.files
  handleFiles(files, 'drop')

init = ->
  console.log "jank"

  filenameElem = document.getElementById('filename')

  for eventName in ['dragenter', 'dragover', 'dragleave', 'drop']
    document.body.addEventListener(eventName, preventDefaults, false)

  document.body.addEventListener('drop', handleDrop, false)

  document.addEventListener 'paste', (event) ->
    items = (event.clipboardData || event.originalEvent.clipboardData).items
    for item in items
      if item.kind == 'file'
        blob = item.getAsFile()
        reader = new FileReader()
        reader.onload = (event) ->
          initImage("paste", "paste", event.target.result)
        reader.readAsDataURL(blob)

init()
