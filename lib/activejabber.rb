module ActiveJabber
  class Base
    # Returns memoizes and returns a Jabber object, will try to reconnect if disconnected.
    def jabber
      if @jabber
        if @jabber.connected?
          return @jabber
        else
          @jabber.reconnect
        end
      else
        @jabber = Jabber::Simple.new(@username, @password)
      end
      return @jabber
    end
    def initialize(username, password)
      @username = username
      @password = password
    end
    # Used to initiate the smart chaining logic.
    def method_missing(method, *args)
      request_parts = []
      Base::Request.new(self, nil, request_parts).send(method, *args)
    end
    # Sends a request to the client, path should be formatted like "/users" and @opts@ may include a @:args@ (a string) and @:timeout@ (in seconds) keys.
    def request(path, opts)
      hash = self.generate_hash
      message = hash + ':' + path.gsub(/\?$/, '')
      if opts[:args]
        message += ('?' + opts[:args])
      end
      
      self.jabber.deliver(Jabber::JID.new('accounts@madelike.com'), message)
      start = Time.now
      while (Time.now - start) < opts[:timeout]
        self.jabber.received_messages do |msg|
          if msg.body.strip.starts_with?(hash) and msg.from.to_s.strip.starts_with?('accounts@madelike.com')
            parts = msg.body.strip.split(':', 3)
            data = (parts[2].nil? ? '' : parts[2].strip)
            if opts[:format] == :json
              data = ActiveSupport::JSON.decode(data)
            end
            response = {:status => parts[1].to_i, :data => data}
            response[:latency] = (Time.now - start)
            return response
          end
        end
      end
      if (Time.now - start) >= opts[:timeout]
        return {:status => 408, :data => '', :latency => (Time.now - start)} # Request timeout
      end
    end
    # Creates a random hash used to uniquely identify each method.
    def generate_hash
      ActiveSupport::SecureRandom.hex(8) # Generates 16 character hexdecimal string.
    end
    
    class Request
      attr_accessor :parts
      
      def initialize(base, part, parts)
        @base = base
        @parts = parts
        unless part.nil?
          @parts << ('/' + part.to_s)
        end
      end
      # Determines if this is a known format.
      def parse_format(method)
        if method.to_s == 'json' or method.to_s == 'json?'
          :json
        elsif method.to_s == 'text' or method.to_s == 'text?'
          :text
        end
      end
      # The chainable magic happens here.
      def method_missing(method, *args)
        if args.length > 0 or self.parse_format(method) or method.to_s.ends_with? '!'
          format = self.parse_format(method)
          opts = {
            :format => (format or :text),
            :args => '',
            :timeout => 5.0
          }
          if args.length >= 1
            # TODO: Logic to handle other ways of transforming data into a sendable format.
            if args.first.respond_to? :to_s
              opts[:args] = args.first.to_s
            end
            if args.second.is_a? Hash
              opts.merge! args.second
            end
          end
          if args.first.is_a? Hash
            opts.merge! args.first
          end
          # TODO: Support more formats.
          if format == :json
            @parts << '.json'
          else
            @parts << ('/' + method.to_s.gsub(/[?!]$/, ''))
          end
          @base.request(@parts.join(''), opts)
        else
          Request.new(@base, method, @parts)
        end
      end
    end
  end
end