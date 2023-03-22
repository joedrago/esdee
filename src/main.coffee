CSON = require 'cson'
fs = require 'fs'

DiscordBot = require './DiscordBot'
SDWorker = require './SDWorker'

main = ->
  config = CSON.parse(fs.readFileSync("esdee.config"))

  if not config?.discordBotToken?
    console.error "Please supply a esdee.config containing a valid discordBotToken property."
    return

  if Array.isArray(config.discordBotToken)
    botTokens = config.discordBotToken
  else
    botTokens = [config.discordBotToken]

  if not config?.models?
    console.error "Please supply at least one model."
    return
  # TODO: Do better model input validation here

  console.log "Config:", config

  prefix = "#sd"
  if config.prefix?
    prefix = config.prefix

  worker = new SDWorker(prefix, config.models, config.overrides, config.aliases)

  for botToken in botTokens
    bot = new DiscordBot(prefix, botToken)
    bot.on 'ready', (tag) ->
      console.log "Logged in:", tag
    bot.on 'request', (req) ->
      console.log "Request: \"#{req.raw}\""
      worker.request(req)
    bot.login()

main()
