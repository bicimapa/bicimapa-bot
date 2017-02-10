require 'facebook/messenger'
require 'redis'
require 'graphql/client'
require 'graphql/client/http'
require 'state_machines'

$redis = Redis.new(host: 'redis')

$HTTP = GraphQL::Client::HTTP.new("https://bicimapa.com/graphql")
$Schema = GraphQL::Client.load_schema($HTTP)
$Client = GraphQL::Client.new(schema: $Schema, execute: $HTTP)

QUERY  = $Client.parse <<-'GRAPHQL'
	query ($lng: Float!, $lat: Float!, $category_id: ID!) {
		nearSites(lng: $lng, lat: $lat, category_id: $category_id, limit: 5) {
		    name
		    longitude
		    latitude
		    distance
		    path
		}
	}
GRAPHQL

BASE_URL = "https://bicimapa.com"

class BicimapaBot

  attr_reader :session

  def initialize(session)
    super()
   
    @session = session
    @state = if session["state"].nil? then "welcoming" else session["state"] end
    @message = nil

  end

  def process_message(message)
    @message = message
    reply_message
  end

  def process_postback(postback)
    @postback = postback
    reply_postback
  end

  def reply_postback
    if @postback.payload == "GET_STARTED_PAYLOAD"
      @message = @postback
      show_help
    end
  end

  state_machine :state do	

    event :go_back_to_welcoming do
      transition all - [] => :welcoming
    end

    event :wait_for_location do
      transition welcoming: :location_received
    end

    event :wait_for_category do
      transition location_received: :category_received
    end

    state :welcoming do
      def reply_message
	show_help
	wait_for_location
      end
    end

    state :location_received do
      def reply_message
        if is_location_attachment
	  session[:latlng] = @message.attachments.first['payload']['coordinates']
	  show_category_choice
          wait_for_category
        else
	  @message.reply(text: 'Dónde estas ubicado?');
        end
      end
    end

    state :category_received do
      def reply_message
        if ['PARKING_PAYLOAD', 'REPAIR_SHOP_PAYLOAD', 'SHOP_PAYLOAD'].include?(@message.quick_reply)
			
		mark_as_seen
	        typing_on	

		    category_id = nil
		  
		    case @message.quick_reply
		    when 'PARKING_PAYLOAD'
		      category_id = 2
		    when 'REPAIR_SHOP_PAYLOAD'
		      category_id = 3
		    when 'SHOP_PAYLOAD'
		      category_id = 1
		    end


		    result = $Client.query(QUERY, variables: { category_id: category_id, lat: @session["latlng"]["lat"], lng: @session["latlng"]["long"] })
		  

		    elements = []

		    result.data.nearSites.each do |site|
		      elements << { title: site.name, subtitle: distance(site.distance),
			    buttons: [
			       {
				type:"web_url",
				url:"#{BASE_URL}#{site.path}",
				title:"Ver detalles",
			      },
			      {
				type:"web_url",
				url:"https://www.google.com/maps/dir/#{@session["latlng"]["lat"]},#{@session["latlng"]["long"]}/#{site.latitude},#{site.longitude}",
				title:"LLegar ahi",
			      }
			    ]
			}
		    end

		    typing_off

		    @message.reply(
		      attachment: {
			type: 'template',
			  payload: {
			    template_type: 'generic',
			    elements: elements,
			}
		      }
		    )

		    go_back_to_welcoming
	else
	  show_category_choice
        end
      end
    end

  end

  private
  
  def is_location_attachment
    @message.attachments && @message.attachments.first["type"] == 'location'
  end

  def show_help
	@message.reply text: "Dónde estas ubicado? Dinos y te mostraremos dónde están los parqueaderos, talleres o tiendas más cercanos.",
		quick_replies: [
			{
				content_type: "location",
			}
		]
  end

  def show_category_choice
	@message.reply(
	  text: 'Qué estás buscando ?',
	  quick_replies: [
	    {
	      content_type: 'text',
	      title: 'Parqueadero',
	      payload: 'PARKING_PAYLOAD',
	      image_url: 'https://github.com/bicimapa/bicimapa-assets/blob/master/old-pins/parqueadero.png?raw=true'
	    },
	    {
	      content_type: 'text',
	      title: 'Taller',
	      payload: 'REPAIR_SHOP_PAYLOAD',
	      image_url: 'https://github.com/bicimapa/bicimapa-assets/blob/master/old-pins/taller.png?raw=true'
	    },
	    {
	      content_type: 'text',
	      title: 'Tienda',
	      payload: 'SHOP_PAYLOAD',
	      image_url: 'https://github.com/bicimapa/bicimapa-assets/blob/master/old-pins/tienda.png?raw=true'
	    }
	  ]
	)
  end
  
  def mark_as_seen
    Facebook::Messenger::Bot.deliver(
		    {
  			recipient: @message.sender, 
		        sender_action: 'mark_seen'
		    },
	access_token: ENV['ACCESS_TOKEN'])
  end

  def typing_on
    Facebook::Messenger::Bot.deliver(
		    {
  			recipient: @message.sender, 
		        sender_action: 'typing_on'
		    },
	access_token: ENV['ACCESS_TOKEN'])
  end

  def typing_off
    Facebook::Messenger::Bot.deliver(
		    {
  			recipient: @message.sender, 
		        sender_action: 'typing_off'
		    },
	access_token: ENV['ACCESS_TOKEN'])
  end

end


include Facebook::Messenger

def distance(distance_in_m)

	return "#{distance_in_m.round} m" if distance_in_m < 1000

	return "#{(distance_in_m/1000).round(1)} km"	

end

def get_session(id)
	session = $redis.get(id)
	if session.nil?
		return {}
	else
		return JSON.parse session end
end

def set_session(id, data)
	$redis.set(id, data.to_json)
end



Bot.on :postback do |postback|


	sender_id = postback.sender["id"]
	session = get_session(sender_id)

	bot = BicimapaBot.new(session)
	bot.process_postback(postback)

	session["state"] = bot.state
	set_session sender_id, session

end

Bot.on :message do |message|

	sender_id = message.sender["id"]
	session = get_session(sender_id)

	bot = BicimapaBot.new(session)
	bot.process_message(message)

        session = bot.session
	session["state"] = bot.state
	set_session sender_id, session

end