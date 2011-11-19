class Model
  def initialize(id)
    @id = id
  end
  
  def ==(other)
    @id.to_s == other.id.to_s
  end
  
  attr_reader :id
  
  def self.property(name)
    klass = self.name.downcase
    self.class_eval <<-RUBY
      def #{name}
        _#{name}
      end
      
      def _#{name}
        redis.get("#{klass}:id:" + id.to_s + ":#{name}")
      end
      
      def #{name}=(val)
        redis.set("#{klass}:id:" + id.to_s + ":#{name}", val)
      end
    RUBY
  end
  
end

class Event < Model
  def self.find(event_id)
    if redis.exists "event:id:#{event_id}:name"
      Event.new(event_id)
    end
  end
  
  def self.create(name, options = {})
    event_id = redis.incr 'event_id'      
    
    redis.set "event:id:#{event_id}:name", name
    redis.set "event:id:#{event_id}:date", options[:date]
    redis.set "event:id:#{event_id}:location", options[:location]
    redis.set "event:id:#{event_id}:description", options[:description]
    
    redis.rpush 'event_list', event_id
    
    redis.sadd "event:date:#{options[:date]}", event_id
    Event.new(event_id)
  end
  
  def self.all
    redis.lrange("event_list", 0, -1).map{|event_id| Event.new(event_id)} if redis.exists "event_list"
  end
  
  def self.last_added
    events = Event.all
    events.reverse!.slice!(0..10) if events 
  end
  
  def self.find_by_date(date)
    redis.smembers("event:date:#{date}").map{|event_id| Event.new(event_id)} if redis.exists "event:date:#{date}"
  end
  
  def self.comming_soon
    # wtf any better way to do it?
    date = Date.today.prev_day
    1.upto(5).map{
      date = date.next_day 
      Event.find_by_date(date)
    }.flatten.compact # all to an array, without nils
  end
  
  property :name
  property :date
  property :location
  property :description

  
  # should the model know the path?
  def path
    "events/#{id}/#{name}"
  end
  
  def members
    # is it okay to check if exists in here?
    redis.smembers("event:id:#{id}:members").map{|username| Member.new(username)} if redis.exists "event:id:#{id}:members" 
  end
  
  def add_attendee(member)
    redis.sadd "event:id:#{id}:members", member.id
    redis.sadd "member:id:#{member.id}", id
  end
end


class Member < Model
  def self.create(username)
    username.gsub!("@","")
    Member.new(username)
  end
  
  def path
    "members/#{id}"
  end
end
