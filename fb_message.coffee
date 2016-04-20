_ = require 'lodash'
fs = require 'fs'
Mustache = require 'mustache'
Request = require 'request'
remove_md = require 'remove-markdown'

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

  channel: ->
    "FB Messenger Channel"

  user:->
    {"id":@msg.sender.id,"profile":{"email":"msg.sender.id@facebook.com"}}

  send_menu: (menu)->
    elements = _.sortBy _.compact(_.flatten([menu.food, menu.beverages, menu.special_items ])), (opt)-> -Number(opt.available)
    @send([menu.title, menu.hood].join(' '))
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: "template"
          payload:
            template_type: "generic"
            elements: _.map _.take(elements, 10), (opt)->
              strip_name = opt.name.replace(/ y /g, ' ')
              element = {
                title: if opt.available then "$#{opt.price} - #{opt.name}" else "AGOTADO - #{opt.name}"
                subtitle: opt.description
                image_url: opt.picture
              }
              if opt.available
                element.buttons = [{
                  title: "Agregar"
                  type: "postback"
                  payload: strip_name
                },
                {
                  title: "Quitar"
                  type: "postback"
                  payload: "quitar #{strip_name}"
                }]
              element
    })

  send_yesno: (question, options)->
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: "template"
          payload:
            template_type: "button"
            text: question
            buttons: _.map(options, (o)->
              {
                type: "postback"
                title: o
                payload: o
              }
            )
    })

  send_receipt: (info)->
      groups = _.groupBy info.options, (option)-> option.id
      grouped_options = _.values(groups)
      send_message({
        recipient: {id: @user().id}
        message:
          attachment:
            type: 'template'
            payload:
              template_type: "receipt"
              recipient_name: info.customer.name
              order_number: info.order_id
              payment_method: info.customer.payment
              currency: 'ARS'
              elements: _.map(grouped_options, (opts)->
                opt = _.first(opts)
                {
                  title: opt.name
                  price: opt.price
                  image_url: opt.picture
                  subtitle: opt.description
                  quantity: _.size(opts)
                  currency: 'ARS'
                }
              )
              summary:
                total_cost: _.sum _.pluck(info.options, 'price')
      })
      if info.customer.payment isnt 'cash'
        send_message({
          recipient: {id: @user().id}
          message:
            attachment:
              type: "template"
              payload:
                text: "Continuar el pago en:"
                template_type: "button"
                buttons: [{
                  type: "web_url",
                  url: info.payment_url
                  title: "#{info.customer.payment}"
                }]
        })

      send_message({
        recipient: {id: @user().id}
        message:
          text: "compartí http://m.me/hoypido con tus amigos para que también pidan comida por Facebook Messenger™"
      })

  send_addresses: (question, end_message, options, n=1, send_question=yes)->
    @send('seleccioná la dirección correcta')
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: "template"
          payload:
            template_type: "generic"
            elements: _.map options, (opt, index)->
              element = {
                title: opt
                subtitle: opt
                image_url: "https://maps.googleapis.com/maps/api/staticmap?size=400x200&format=png&center=#{opt}&markers=color:orange|#{opt}"
                buttons: [{
                    title: "Seleccionar"
                    type: "postback"
                    payload: ""+(index + n)
                }]
              }
    })
  send_options: (question, end_message, options, n=1, send_question=yes)->
    new_options = _.compact(_.take(options, 3))
    if !new_options.length
      return yes
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: "template"
          payload:
            template_type: "button"
            text: if send_question then remove_md(question) else "o sino :"
            buttons: _.map(new_options, (o, index)->
              {
                type: "postback"
                title: o
                payload: ""+(index + n)
              }
            )
    })
    return @send_options(question, end_message, options.slice(3),n+3, no)

  send: (message)->
    send_message({
      recipient: {id: @user().id}
      message:
        text: remove_md(message)
    })
    # send_next()

  post_message: (message)->
    send_message({
      recipient: {id: @user().id}
      message:
        attachment:
          type: 'image'
          payload:
            url:  _.first(message.attachments).image_url
    })
    # send_next()

  bot_id: ->
    @msg.recipient.id

  text: ->
    if @msg.message then @msg.message.text else @msg.postback.payload

  getTeam: -> undefined

  is_channel: -> no

  get_user_id: -> return { fb_id: @user().id }

module.exports = FBMessage
