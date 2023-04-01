{ EventEmitter } = require 'node:events'

Discord = require 'discord.js'

class DiscordBot
  constructor: (@prefix, @secret) ->
    @emitter = new EventEmitter
    @on = @emitter.on.bind(@emitter)

    @discordClient = new Discord.Client({ partials: [
      Discord.Partials.Channel
    ], intents: [
      Discord.IntentsBitField.Flags.Guilds
      Discord.IntentsBitField.Flags.GuildMessages
      Discord.IntentsBitField.Flags.DirectMessages
      Discord.IntentsBitField.Flags.DirectMessageReactions
      Discord.IntentsBitField.Flags.MessageContent
    ]})
    @discordClient.on 'ready', @discordReady.bind(this)
    @discordClient.on 'messageCreate', @discordMessage.bind(this)

  discordReady: ->
    @discordTag = @discordClient.user.tag
    @emitter.emit 'ready', @discordTag

  discordMessage: (msg) ->
    # console.log msg
    if msg.author.bot
      return
    if msg.content?.length <= 0
      return
    if msg.content.indexOf(@prefix) != 0
      return

    ref = null
    if msg.type == Discord.MessageType.Reply
      ref = await msg.fetchReference()
      if ref.author.id != @discordClient.user.id
        # Only send this if the person is trying to reply to us
        ref = null

    raw = msg.content.substring(@prefix.length).trim()
    req = {
      discordMsg: msg
      raw: raw
      ref: ref
    }

    if msg.attachments?
      msg.attachments.each (a) ->
        if a.url? and ((a.contentType == "image/png") or (a.contentType == "image/jpg") or (a.contentType == "image/jpeg"))
          if not req.images?
            req.images = []
          req.images.push a.url

    req.reply = (text, images) ->
      replyPayload =
        content: text
        allowedMentions:
          repliedUser: false # don't ping the user, it is annoying
      if images?
        replyPayload.files = images.map (im) -> Buffer.from(im, 'base64')
      req.discordMsg.reply replyPayload

    @emitter.emit 'request', req

  login: ->
    @discordClient.login(@secret)

module.exports = DiscordBot
