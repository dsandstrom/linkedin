module LinkedIn
  module Helpers

    module V2Request

      DEFAULT_HEADERS = {
        'x-li-format' => 'json',
        'Content-Type' => 'application/json',
        'X-Restli-Protocol-Version' => '2.0.0'
      }

      API_PATH = '/v2'

      protected

        def v2_get(path, options = {})
          response = access_token.get("#{API_PATH}#{path}",
                                      headers: DEFAULT_HEADERS.merge(options))
          raise_errors(response)
          response.body
        end

        def v2_post(path, body = '', options = {})
          # unscoped_url option necessary for image updload
          # Since Linkedin returns a complete URL for image upload on version 2 (unscoped from v2)
          # we can't scope requests on v2 as well
          # see: https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin?context=linkedin/consumer/context#upload-image-binary-file
          url = options.delete(:unscoped_url) ? path : "#{API_PATH}#{path}"

          options = { body: body, headers: DEFAULT_HEADERS.merge(options) }
          # response is OAuth2::Response
          # response.response is Faraday::Response
          # sending back response.response makes it easier to access the env
          response = access_token.post(url, options).response
          raise_errors(response)
          response
        end

      private

        def raise_errors(response)
          # Even if the json answer contains the HTTP status code, LinkedIn also sets this code
          # in the HTTP answer (thankfully).
          case response.status.to_i
          when 401
            data = Mash.from_json(response.body)
            raise LinkedIn::Errors::UnauthorizedError.new(data), "(#{data.status}): #{data.message}"
          when 400
            data = Mash.from_json(response.body)
            raise LinkedIn::Errors::GeneralError.new(data), "(#{data.status}): #{data.message}"
          when 403
            data = Mash.from_json(response.body)
            raise LinkedIn::Errors::AccessDeniedError.new(data), "(#{data.status}): #{data.message}"
          when 404
            raise LinkedIn::Errors::NotFoundError, "(#{response.status}): #{response.message}"
          when 500
            raise LinkedIn::Errors::InformLinkedInError, "LinkedIn had an internal error. Please let them know in the forum. (#{response.status}): #{response.message}"
          when 502..503
            raise LinkedIn::Errors::UnavailableError, "(#{response.status}): #{response.message}"
          end
        end


        # Stolen from Rack::Util.build_query
        def to_query(params)
          params.map { |k, v|
            if v.class == Array
              to_query(v.map { |x| [k, x] })
            else
              v.nil? ? escape(k) : "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"
            end
          }.join("&")
        end

        def to_uri(path, options)
          uri = URI.parse(path)

          if options && options != {}
            uri.query = to_query(options)
          end
          uri.to_s
        end
    end

  end
end
