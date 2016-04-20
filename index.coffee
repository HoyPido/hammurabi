FBMessage = require './fb_message'
hammurabi = require './hammurabi'

game_status = {}
game_responses = {}
my_last_message = {}


track_strategy = (context, strategy)->
    console.log("[#{context.user.id}] - Strategy - #{strategy}")
    context.visitor.pageview("/hammurabi/#{strategy}").send()

start_game_strategy = (context)->
  if _.isEmpty(context.game_status)
    return yes

resolve = (message)->
  strategies = [
    tutorial_strategy
    start_game_strategy
    ask_for_buy_sell
    ask_for_feed
    ask_for_seed
    tick_strategy
    finish_strategy
  ]

  user = bot_message.user()
  text = bot_message.text()

  context = {
    visitor: ua(app.get('ga-id'), user.id, {strictCidFormat: false})
    user: user
    game_status = game_status[user.id]
    responses = game_responses[user.id]
    send: (message)->
      my_last_message[user.id] = message
      bot_message.send message
    text : message.
  }

  _.any strategies, (strategy)-> strategy(context)


# App create
app = express()
app.set "port", process.env.PORT || 5001
app.set "ga-id", "UA-50696108-1"
json_parser = body_parser.json()
server = http.createServer(app)

app.post '/fb/webhook', json_parser, (request,response)->
    input_message = request.body
    console.log(JSON.stringify(input_message))
    resolve new FBMessage(input_message)
    response.send({success: true})

app.get '/fb/webhook', (request,response)->
  if (request.query['hub.verify_token'] is process.env.FB_MESSENGER_VERIFY_TOKEN)
    response.send(request.query['hub.challenge'])
  else
    response.send('Error, wrong validation token')
