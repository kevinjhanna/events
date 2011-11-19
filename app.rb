require 'sinatra'
require 'redis'
require 'date'
require './models'

def redis
  $redis ||= Redis.new
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  @events = Event.comming_soon
  erb :index
end

post '/' do
  if params[:name] and not params[:name].empty?
    Event.create(params[:name], params)
  end 
  redirect '/'
end

get '/events/:id/:name' do
  @event = Event.find(params[:id])

  if @event.nil?
    erb :index
  else
    erb :event
  end
end

post '/events/:id/:name' do
  @event = Event.find(params[:id])
  if params[:username] and not params[:username].empty?
    member = Member.create(params[:username])
    @event.add_attendee(member)
  end
  redirect "/events/#{params[:id]}/#{params[:name]}"
end