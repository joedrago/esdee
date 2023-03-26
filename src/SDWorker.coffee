fs = require 'fs'
http = require 'http'
https = require 'https'
path = require 'path'
PNG = require('pngjs').PNG
JPEG = require 'jpeg-js'

class SDWorker
  constructor: (@prefix, @models, overrides, aliases) ->
    @queue = []
    @busy = false
    @setDefaults()

    if overrides?
      for name, override of overrides
        if not @paramConfig[name]? and override.default?
          # Allow an entirely new param to come into existence, as long as a
          # default was provided.
          @paramConfig[name] =
            description: name
            default: override.default
        if not @paramConfig[name]?
          console.error "Skipping unknown/incomplete override: #{name}"
          continue
        for k,v of override
          console.log "[Override] #{name}.#{k} = #{v}"
          @paramConfig[name][k] = v

    if aliases?
      for k,v of aliases
        console.log "[Alias] '#{k}' -> '#{v}'"
        @paramAliases[k] = v

  setDefaults: ->
    @paramConfig =
      width:
        description: "Output image width"
        default: 512
        min: 128
        max: 1024
      height:
        description: "Output image height"
        default: 512
        min: 128
        max: 1024
      steps:
        description: "How many times to re-run the model on the output image"
        default: 40
        min: 1
        max: 100
      cfg_scale:
        description: "Classifier Free Guidance scale: How strongly the image should conform to the prompt"
        default: 7
        min: 1
        max: 30
      denoising_strength:
        description: "How closely to match the input image. Low numbers match the image strongly, high numbers throw most of it away"
        default: 0.5
        min: 0.0
        max: 1.0
        float: true
      seed:
        description: "Random seed. Leave at -1 to keep it random, or use the previous seed to recreate the last image"
        default: -1
        min: -1
        max: 2147483647
      batch_size:
        description: "How many images to generate"
        default: 1
        min: 1
        max: 9
      sampler_name:
        description: "Which sampler to use. No, I don't understand it either."
        default: "DPM++ 2M Karras"
        enum: [
          "DDIM"
          "DPM adaptive"
          "DPM fast"
          "DPM++ 2M Karras"
          "DPM++ 2M"
          "DPM++ 2S a Karras"
          "DPM++ 2S a"
          "DPM++ SDE Karras"
          "DPM++ SDE"
          "DPM2 a Karras"
          "DPM2 a"
          "DPM2 Karras"
          "DPM2"
          "Euler a"
          "Euler"
          "Heun"
          "LMS Karras"
          "LMS"
          "PLMS"
        ]

    @paramAliases =
      denoise: "denoising_strength"
      denoising: "denoising_strength"
      dns: "denoising_strength"
      dn: "denoising_strength"
      noise: "denoising_strength"
      de: "denoising_strength"
      cfg: "cfg_scale"
      step: "steps"
      w: "width"
      h: "height"
      sampler: "sampler_name"
      samp: "sampler_name"
      count: "batch_size"
      batch: "batch_size"

  parseParams: (prompt) ->
    rawParams = ""
    if matches = prompt.match(/^\[([^\]]+)\](.*)/)
      rawParams = matches[1]
      prompt = matches[2]
      prompt = prompt.replace(/^[, ]+/, "")

    posNeg = prompt.split(/\|\|/)
    if posNeg.length > 1
      params =
        prompt: posNeg[0].trim()
        negative_prompt: posNeg[1].trim()
    else
      params =
        prompt: prompt

    for name,pc of @paramConfig
      params[name] = pc.default
    # console.log params

    keyName = "denoising_strength"
    pieces = rawParams.split(/[:,\s]+/)
    # console.log pieces
    for piece in pieces
      v = parseFloat(piece)
      if keyName? and not isNaN(v)
        if @paramConfig[keyName].enum?
          v = Math.round(v)
          if (v < 0) or (v > @paramConfig[keyName].enum.length - 1)
            v = 0
          v = @paramConfig[keyName].enum[v]
        else
          if @paramConfig[keyName].min? and v < @paramConfig[keyName].min
            v = @paramConfig[keyName].min
          if @paramConfig[keyName].max? and v > @paramConfig[keyName].max
            v = @paramConfig[keyName].max
          if not @paramConfig[keyName].float
            v = Math.round(v)
        params[keyName] = v
        keyName = null
      else
        keyName = piece.toLowerCase()
        if @paramAliases[keyName]?
          keyName = @paramAliases[keyName]
        if not @paramConfig[keyName]?
          keyName = null

    return params

  downloadUrl: (url) ->
    return new Promise (resolve, reject) ->
      req = https.request url, {
        method: 'GET'
      }, (response) ->
        chunks = []
        response.on 'data', (chunk) ->
          chunks.push chunk
        response.on 'end', ->
          buffer = Buffer.concat(chunks)
          resolve(buffer)
        response.on 'error', ->
          resolve(null)
      req.end()

  setModel: (model) ->
    return new Promise (resolve, reject) ->
      req = http.request {
        host: "127.0.0.1",
        path: "/sdapi/v1/options",
        port: '7860',
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
      }, (response) ->
        str = ''
        response.on 'data', (chunk) ->
          str += chunk
        response.on 'end', ->
          resolve(true)
      req.write(JSON.stringify({
        "sd_model_checkpoint": model
      }))
      req.end()

  decodeImage: (image) ->
    if image.type == 'image/png'
      png = PNG.sync.read(image.buffer)
      image.width = png.width
      image.height = png.height
    else
      # jpeg
      rawjpeg = JPEG.decode(image.buffer)
      image.width = rawjpeg.width
      image.height = rawjpeg.height
    return image

  img2img: (srcImage, srcMask, prompt) ->
    return new Promise (resolve, reject) =>
      params = @parseParams(prompt)

      @decodeImage(srcImage)

      imageAspect = srcImage.width / srcImage.height
      console.log "Decoded image [#{srcImage.type}] #{srcImage.width}x#{srcImage.height} (Aspect: #{imageAspect.toFixed(2)})"
      if imageAspect < 1
        params.height = Math.floor(params.height / 4) * 4
        params.width = Math.floor(params.height * imageAspect / 4) * 4
      else
        params.width = Math.floor(params.width / 4) * 4
        params.height = Math.floor(params.width / imageAspect / 4) * 4

      params.include_init_images = true
      console.log "Params: ", params
      params.init_images = [
        "data:#{srcImage.type};base64," + srcImage.buffer.toString('base64')
      ]

      maskStatus = null
      if srcMask?
        @decodeImage(srcMask)

        if (srcImage.width == srcMask.width) and (srcImage.height == srcMask.height)
          maskStatus = "inpainting_fill"
          params.inpainting_fill = 1
          params.mask = "data:#{srcMask.type};base64," + srcMask.buffer.toString('base64')
        else
          maskStatus = "inpainting_ignored_bad_mask_dims"

      req = http.request {
        host: "127.0.0.1",
        path: "/sdapi/v1/img2img",
        port: '7860',
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
      }, (response) ->
        str = ''
        response.on 'data', (chunk) ->
          str += chunk
        response.on 'end', ->
          data = null
          try
            data = JSON.parse(str)
            delete params["init_images"]
            delete params["include_init_images"]
            if maskStatus?
              params.mask = maskStatus
            data.esdeeParams = params
          catch
            console.log "Bad JSON: #{str}"
            data = []
          resolve(data)

      req.write(JSON.stringify(params))
      req.end()

  txt2img: (prompt) ->
    return new Promise (resolve, reject) =>
      params = @parseParams(prompt)
      params.width = Math.floor(params.width / 4) * 4
      params.height = Math.floor(params.height / 4) * 4
      console.log "Params: ", params

      req = http.request {
        host: "127.0.0.1",
        path: "/sdapi/v1/txt2img",
        port: '7860',
        method: 'POST'
        headers:
          'Content-Type': 'application/json'
      }, (response) ->
        str = ''
        response.on 'data', (chunk) ->
          str += chunk
        response.on 'end', ->
          data = null
          try
            data = JSON.parse(str)
            data.esdeeParams = params
          catch
            console.log "Bad JSON: #{str}"
            data = []
          resolve(data)

      req.write(JSON.stringify(params))
      req.end()

  kick: ->
    setTimeout =>
      @process()
    , 0

  process: ->
    if @busy
      return
    if @queue.length == 0
      return

    @busy = true
    req = @queue[0]

    await @diffusion(req)
    @queue.shift()
    @busy = false
    @kick()

  syntax: (req, reason) ->
    output = ""

    if reason?
      output += "**Error**: #{reason}\n\n"
    else
      output += "Stable Diffusion Help:\n\n";

    output += "Available models:\n"
    for trigger, model of @models
      output += " * **#{@prefix} #{trigger}** - _#{model.desc}_\n"

    output += "\nSyntax:\n\`\`\`\n"
    output += "#{@prefix} MODELNAME some prompt\n"
    output += "#{@prefix} MODELNAME [steps 10 cfg 3] some prompt\n"
    output += "#{@prefix} MODELNAME some prompt || some negative prompt\n"
    output += "#{@prefix} MODELNAME [steps 10 cfg 3] some prompt || some negative prompt\n"
    output += "\`\`\`\n"
    output += "**Attach an image** to your request to use it as an input!\n"
    output += "\nTune params by putting pairs inside \`[]\` (see above).\n"
    output += "Get the full list of tunable parameters by asking for the config with **#{@prefix} config**\n"
    output += "\n"

    req.reply output
    return true

  queryConfig: (req) ->
    pad = (s, count) ->
      return ("                   " + s).slice(-1 * count)

    o = "```\n"
    o += "SD Worker Config\n";
    o += "----------------\n";

    for pcName, pc of @paramConfig
      pcAliases = []
      for paName, pa of @paramAliases
        if pcName == pa
          pcAliases.push paName

      o += "\n* #{pcName} - #{pc.description}\n"
      if pcAliases.length > 0
        o += "  Aliases: #{pcAliases.join(', ')}\n"
      o += "  Default: #{pc.default}\n"
      if pc.enum?
        o += "  Choices: (pick a number)\n"
        for pcChoice, pcChoiceIndex in pc.enum
          o += "    #{pad(pcChoiceIndex, 2)}: #{pcChoice}\n"
      else if pc.min? and pc.max?
        if pc.float?
          o += "  Range  : [#{pc.min.toFixed(1)}, #{pc.max.toFixed(1)}]\n"
        else
          o += "  Range  : [#{pc.min}, #{pc.max}]\n"

    o += "```"

    console.log "Config Replying: [#{o.length}]"
    req.reply o

  queryQueue: (req) ->
    if @queue.length == 0
      o = "The queue is empty."
    else if @queue.length == 1
      o = "The queue has 1 entry."
    else
      o = "The queue has #{@queue.length} entries."
    console.log o
    req.reply o

  request: (req) ->
    matches = req.raw.match(/^([^\s,]+),?\s*(.*)/)
    if not matches?
      @syntax(req)
      return
    req.modelName = matches[1]
    req.prompt = matches[2]

    # Intrinsic subcommands (you may not name a model one of these)
    if req.modelName == "help"
      @syntax(req)
      return
    if req.modelName == "config"
      @queryConfig(req)
      return
    if req.modelName == "queue"
      @queryQueue(req)
      return

    if not @models[req.modelName]?
      @syntax(req, "No such model: #{req.modelName}")
      return

    @queue.push req
    req.reply "Queued: [#{@queue.length}]"
    @kick()

  diffusion: (req) ->
    modelName = req.modelName
    prompt = req.prompt

    modelInfo = @models[modelName]
    model = modelInfo.model
    if modelInfo.suffix?
      prompt += ", #{modelInfo.suffix}"

    imageType = 'image/png'

    srcImage = null
    srcMask = null
    if req.images? and req.images.length > 0
      for imageURL in req.images
        url = new URL(imageURL)
        pieces = path.parse(url.pathname)
        outImage =
          type: 'image/png'
        if (pieces.ext == '.jpg') or (pieces.ext == '.jpeg')
          outImage.type = 'image/jpeg'
        if not srcImage?
          outImageDescription = "srcImage"
          srcImage = outImage
        else if not srcMask?
          outImageDescription = "srcMask"
          srcMask = outImage
        else
          # We don't need any more images
          break
        outImage.buffer = await @downloadUrl(imageURL)
        console.log "#{outImageDescription}[#{outImage.buffer.length}][#{outImage.type}]: #{imageURL}"

    console.log "Configuring model: #{model}"
    await @setModel(model)

    # req.reply "Started [#{model}]"

    startTime = +new Date()
    if srcImage?
      console.log "img2img[#{srcImage.buffer.length}]: #{prompt}"
      result = await @img2img(srcImage, srcMask, prompt)
    else
      console.log "txt2img: #{prompt}"
      result = await @txt2img(prompt)
    endTime = +new Date()
    timeTaken = endTime - startTime

    try
      outputSeed = JSON.parse(result.info).seed
    catch
      outputSeed = -1

    result.esdeeParams.seed = outputSeed

    message = {}
    if result? and result.images? and result.images.length > 0
      console.log "Received #{result.images.length} images..."
      message.text = "Complete [#{model}][#{(timeTaken/1000).toFixed(2)}s]: `#{JSON.stringify(result.esdeeParams)}`\n"
      message.images = result.images
    else
      message.text = "**FAILED**: [#{model}] #{prompt}"

    console.log "Replying: [#{message.text}][#{message.images?.length}]"
    req.reply(message.text, message.images)


module.exports = SDWorker
