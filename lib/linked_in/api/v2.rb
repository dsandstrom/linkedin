module LinkedIn
  module Api

    # V2 Consumer API
    #
    # @see https://docs.microsoft.com/en-us/linkedin/consumer/
    module V2

      # Obtain profile information for a member.  Currently, the method only
      # accesses the authenticated user.
      #
      # Permissions: r_liteprofile
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin?context=linkedin/consumer/context#retrieving-member-profiles
      #
      # @return [void]
      def v2_profile
        fields = ['id', 'firstName', 'lastName', 'profilePicture(displayImage~:playableStreams)'] # Default fields
        path = "/me?projection=(#{fields.join(',')})"
        parse_profile_data v2_get(path)
      end

      # Obtain email information for a member.  Currently, the method only
      # accesses the authenticated user.
      #
      # Permissions: r_emailaddress
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin?context=linkedin/consumer/context#retrieving-member-email-address
      #
      # @return [void]
      def v2_email_address
        path = '/emailAddress?q=members&projection=(elements*(handle~))'
        JSON.parse(v2_get(path))['elements'][0]['handle~']['emailAddress']
      end

      # Share content for the authenticated user
      #
      # Permissions: w_member_share
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin
      #
      # @param [String] urn   User's URN (UID) returned from OAuth access token
      #                       request
      # @param [Hash]   share The body we want to submit to LinkedIn. At least a
      #                       comment is required
      #
      # @macro share_input_fields
      # @return [void]
      def v2_add_share(urn, share = {})
        if !urn.instance_of?(String) || urn.empty?
          raise LinkedIn::Errors::UnavailableError, 'LinkedIn API: URN required'
        elsif share[:comment].nil?
          raise LinkedIn::Errors::UnavailableError,
                'LinkedIn API: Comment required'
        end

        path = '/ugcPosts'
        v2_post(path, MultiJson.dump(share_payload(urn, share)))
      end

      private

        def share_payload(urn, share)
          payload = { author: "urn:li:person:#{urn}",
            lifecycleState: 'PUBLISHED',
            visibility: {
              'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC'
            }
          }

          return add_url_to_payload(payload, share) if share[:url]

          add_comment_to_payload(payload, share)
        end

        def add_url_to_payload(payload, share)
          media = { status: 'READY', originalUrl: share[:url] }
          if share[:description]
            media[:description] = { text: share[:description] }
          end
          if share[:title]
            media[:title] = { text: share[:title] }
          end
          payload[:specificContent] = {
            'com.linkedin.ugc.ShareContent' => {
              shareCommentary: { text: share[:comment] },
              shareMediaCategory: 'ARTICLE',
              media: [media]
            }
          }
          payload
        end

        def add_comment_to_payload(payload, share)
          payload[:specificContent] = {
            'com.linkedin.ugc.ShareContent' => {
              shareCommentary: { text: share[:comment] },
              shareMediaCategory: 'NONE'
            }
          }
          payload
        end

        def parse_profile_data(raw_json)
          parsed_json = JSON.parse(raw_json)

          data = {
            'id' => parsed_json['id'],
            'first_name' => parse_profile_localized_field(parsed_json, 'firstName'),
            'last_name' => parse_profile_localized_field(parsed_json, 'lastName')
          }

          if !parsed_json['profilePicture'].nil? &&
             !parsed_json['profilePicture']['displayImage~'].nil? &&
             !parsed_json['profilePicture']['displayImage~']['elements'].nil? &&
             !parsed_json['profilePicture']['displayImage~']['elements'].empty?
            data['picture_url'] = parsed_json['profilePicture']['displayImage~']['elements'].last['identifiers'].first['identifier']
          end

          data
        end

        def parse_profile_localized_field(parsed_json, field_name)
          return unless parse_profile_localized_field_available?(parsed_json, field_name)
          parsed_json[field_name]['localized'][parse_profile_field_locale(parsed_json, field_name)]
        end

        def parse_profile_field_locale(parsed_json, field_name)
          "#{parsed_json[field_name]['preferredLocale']['language']}_" \
            "#{parsed_json[field_name]['preferredLocale']['country']}"
        end

        def parse_profile_localized_field_available?(parsed_json, field_name)
          parsed_json[field_name] && parsed_json[field_name]['localized']
        end
    end
  end
end
