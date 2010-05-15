module ActiveJabber
  class Base
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
    def method_missing(method, *args)
      request_parts = []
      Base::Request.new(self, nil, request_parts).send(method, *args)
    end
    def request(path, opts)
      hash = self.generate_hash
      message = hash + ':' + path.gsub(/\?$/, '')
      if opts[:args]
        message += ('?' + opts[:args])
      end
      unless opts[:timeout]
        opts[:timeout] = 5.0
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
      def parse_format(method)
        if method.to_s == 'json' or method.to_s == 'json?'
          :json
        elsif method.to_s == 'text' or method.to_s == 'text?'
          :text
        end
      end
      def method_missing(method, *args)
        if args.length > 0 or self.parse_format(method) or method.to_s.ends_with? '!'
          format = self.parse_format(method)
          opts = {
            :format => (format or :text),
            :args => ''
          }
          if (args.second.is_a? Hash or args.second.nil?) and format == :json
            if args.first
              opts[:args] = (args.first.is_a?(String) ? args.first : args.first.to_json)
            end
            if args.second
              opts.merge! args.second
            end
          elsif args.first.is_a? Hash
            opts.merge! args.first
          elsif args.first.respond_to? :to_s
            opts[:args] = args.first.to_s
            if args.second.is_a? Hash
              opts.merge! args.second
            end
          end
          if format == :json
            @parts << '.json'
          else
            @parts << ('/' + method.to_s.gsub(/!$/, ''))
          end
          
          @base.request(@parts.join(''), opts)
        else
          Request.new(@base, method, @parts)
        end
      end
    end
  end
end