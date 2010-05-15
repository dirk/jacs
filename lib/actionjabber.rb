module ActionJabber
  class Base
    class << self
      @@routes = []
      def route(path, opts = {}, &block)
        @@routes << [path, opts, block]
      end
      def route!(request)
        @@request = request
        @@routes.each do |route|
          if route.first == request.path
            instance_eval do
              result = route.last.call
              self.reset!
              return result
            end
          end
        end
      end
      def request
        @@request
      end
      def reset!
        @@request = nil
      end
    end
  end
  class Server
    def initialize(username, password, controller)
      @jabber = Jabber::Simple.new(username, password)
      @controller = controller # Should be a class.
    end
    def run!
      while @jabber.connected?
        @jabber.received_messages do |message|
          start = Time.now
          
          from = message.from.to_s.split('/').first
          parts = message.body.strip.split(':', 2)
          hash = parts.first
          path_parts = parts.last.split('?', 2)
          request = Request.new(hash, from, path_parts.first, ((path_parts.length == 2) ? path_parts.last : ''))
          begin
            #process_message(message.from.to_s.strip, message.body.strip)
            response = {:status => 200, :data => ''}.merge @controller.route!(request)
            #response = @controller.route! request
            respond_to request, :status => response[:status], :data => response[:data]
          rescue
            respond_to request, :status => 500
            puts "Error responding to #{message.from.to_s.strip}:"
            puts $!
          else
            puts "Responded to '#{from}' in #{(Time.now - start).to_s} seconds."
          end
          puts "\n"
        end
      end
    end
    def respond_to(request, opts = {})
      from = request.from
      status = opts[:status] or 200
      data = opts[:data] or ''
      resp = "#{request.hash}:#{opts[:status]}"
      unless data.to_s.empty?
        resp += (':' + data.to_s)
      end
      @jabber.deliver(Jabber::JID.new(request.from), resp)
    end
    
    class Request
      attr_reader :hash, :format, :from, :path, :args
      
      def initialize(hash, from, path, args)
        @hash = hash
        @from = from
        @path = path
        begin
          @format = path.match(/\.([A-z]+)$/).to_a[1].to_sym
        rescue
          @format = nil
        end
        @args = args
      end
    end
  end
end