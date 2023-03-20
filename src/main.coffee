CSON = require 'cson'
fs = require 'fs'

DiscordBot = require './DiscordBot'
SDWorker = require './SDWorker'

main = ->
  config = CSON.parse(fs.readFileSync("esdee.config"))
  console.log "Config:", config

  if not config?.discordBotToken?.length
    console.error "Please supply a esdee.config containing a valid discordBotToken property."
    return

  if not config?.models?
    console.error "Please supply at least one model."
    return
  # TODO: Do better model input validation here

  prefix = "#sd"
  if config.prefix?
    prefix = config.prefix

  worker = new SDWorker(prefix, config.models)
  bot = new DiscordBot(prefix, config.discordBotToken)
  bot.on 'ready', (tag) ->
    console.log "Logged in:", tag
  bot.on 'request', (req) ->
    console.log "Request: \"#{req.raw}\""
    worker.request(req)
  bot.login()

main()
