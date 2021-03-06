module ActionJabber
  class Base
    class << self
      @@routes = []
      # Used in the controller definition to create routes.
      #   route '/users' do; end
      def route(path, opts = {}, &block)
        @@routes << [path, opts, block]
      end
      # Called by the backend to route a request and return a response. Calling this manually is not recommended.
      def route!(request)
        @@request = request
        @@routes.each do |route|
          if route.first == request.path
            return route.last.call
            break
          end
        end
      end
      # Returns the current request.
      def request
        @@request
      end
    end
  end
  class Server
    # Sets up the server. The +controller+ argument is expected to be a class, not an instance.
    def initialize(username, password, controller, debug = false)
      @jabber = Jabber::Simple.new(username, password)
      @controller = controller # Should be a class.
      @debug = debug
    end
    # Initiates the loop to check for new messages.
    def run!(frequency = 0)
      while @jabber.connected?
        @jabber.received_messages do |message|
          start = Time.now
          
          from = message.from.to_s.split('/').first
          parts = message.body.strip.split(':', 2)
          hash = parts.first
          path_parts = parts.last.split('?', 2)
          request = Request.new(hash, from, path_parts.first, ((path_parts.length == 2) ? path_parts.last : ''))
          # TODO: DRY this portion up.
          if @debug
            # Allow errors to fall through and kill the process.
            controller_response = @controller.route!(request)
            response = {:status => 200, :data => ''}.merge(controller_response)
            respond_to request, :status => response[:status], :data => response[:data]
            puts "Responded to '#{from}' in #{(Time.now - start).to_s} seconds."
          else
            # Capture the errors so that the server keeps on running.
            begin
              controller_response = @controller.route!(request)
              response = {:status => 200, :data => ''}.merge(controller_response)
              respond_to request, :status => response[:status], :data => response[:data]
            rescue
              respond_to request, :status => 500
              puts "Error responding to #{message.from.to_s.strip}:"
              puts $!
            else
              puts "Responded to '#{from}' in #{(Time.now - start).to_s} seconds."
            end
          end
          #puts "\n"
        end
        if frequency > 0
          # Keep it from hogging up CPU cycles.
          sleep frequency
        end
      end
    end
    # Handles actually sending response data to the client.
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
      
      # Sets up the request object.
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