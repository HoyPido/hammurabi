_ = require 'lodash'
fs = require 'fs'
Mustache = require 'mustache'
Request = require 'request'

pending_msgs = []
sending = no

send_json = (json)->
  sending = yes
  Request {
      url: "https://graph.facebook.com/v2.6/me/messages"
      method: 'POST'
      qs:
        access_token: process.env.FB_MESSENGER_PAGE_TOKEN
      json: json
  }, (err, res, body)->
    console.log(body)
    sending = no
    send_next()

send_message = (json)->
  pending_msgs.push(json)
  send_next()
  return yes

send_next = ()->
  if sending
    return
  msg = pending_msgs.shift()
  console.log("Sending #{JSON.stringify(msg)}")
  if msg
    send_json(msg)

class FBMessage
  constructor: (@fbmessage)->
    @entry  =_.last(@fbmessage.entry)
    @msg = _.last(@entry.messaging)

  user:->
    {"id":@msg.sender.id}}

  send: (message)->
    send_message({
      recipient: {id: @user().id}
      message:
        text: remove_md(message)
    })

  post_message: (message)->
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: 'image'
          payload:
            url:  _.first(message.attachments).image_url
    })

  bot_id: ->
    @msg.recipient.id

  text: ->
    if @msg.message then @msg.message.text else @msg.postback.payload
module.exports = FBMessage
