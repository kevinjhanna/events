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
    event = Event.new(event_id)
    
    event.name = name
    event.date = options[:date]
    event.location =  options[:location]
    event.description = options[:description]
    
    redis.rpush 'event_list', event_id
    redis.zadd "event:date", Date.parse(options[:date]).to_time.to_i, event_id
    
    return event
  end
  
  def self.all
    redis.lrange("event_list", 0, -1).map{|event_id| Event.new(event_id)} if redis.exists "event_list"
  end
  
  def self.last_added
    events = Event.all
    events.reverse!.slice!(0..10) if events 
  end
  
  def self.find_by_date(date)
    # date is an instance of Date
    score = date.to_time.to_i
    if redis.exists "event:date"
      redis.zrangebyscore("event:date", score, score).map{|event_id|
        Event.new(event_id)
      }.compact 
    end
  end
  
  def self.comming_soon
    if redis.exists "event:date"
      from  = Date.today.to_time.to_i
      up_to = Date.today.next_month.to_time.to_i
        redis.zrangebyscore('event:date', from, up_to).map{|event_id|
          Event.new(event_id)
        }.compact # without nils 
    end
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
