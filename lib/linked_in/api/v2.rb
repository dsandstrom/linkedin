module LinkedIn
  module Api

    # V2 Consumer API
    #
    # @see https://docs.microsoft.com/en-us/linkedin/consumer/
    module V2

      # Obtain profile information for a member.  Currently, the method only
      # accesses the authenticated user.
      #
      # Permissions: r_liteprofile r_emailaddress
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin?context=linkedin/consumer/context#retrieving-member-profiles
      #
      # @return [void]
      def v2_profile
        path = '/me'
        v2_get(path)
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

      # Request an image updload URL for the authenticated user
      #
      # Permissions: w_member_share
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin?context=linkedin/consumer/context#create-an-image-share
      #
      # @param [String] urn   User's URN (UID) returned from OAuth access token
      #                       request
      #
      # @return [void]
      def v2_request_image_upload_url(urn)
        if !urn.instance_of?(String) || urn.empty?
          raise LinkedIn::Errors::UnavailableError, 'LinkedIn API: URN required'
        end

        path = '/assets?action=registerUpload'
        v2_post(path, MultiJson.dump(v2_request_image_upload_payload(urn)))
      end

      # Upload image asset from a requested image upload url
      #
      # Permissions: w_member_share
      #
      # @see https://docs.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/share-on-linkedin?context=linkedin/consumer/context#upload-image-binary-file
      #
      # @param [String] url Url requested from `v2_request_image_upload_url`
      # @param [Binary] body A Binary file Content
      #
      # @return [void]
      def v2_upload_image(url, body)
        v2_post(url, body, upload_file_headers)
      end

      private

        def upload_file_headers
          {
            'Content-type': 'application/octet-stream',
            unscoped_url: true
          }
        end

        def share_payload(urn, share)
          visbility = share[:visibility] || 'PUBLIC'

          payload = {
            author: "urn:li:person:#{urn}",
            lifecycleState: 'PUBLISHED',
            specificContent: {
              'com.linkedin.ugc.ShareContent' => {
                shareCommentary: { text: share[:comment] },
                shareMediaCategory: 'NONE',
              }
            },
            visibility: {
              'com.linkedin.ugc.MemberNetworkVisibility' => visbility
            }
          }

          return add_url_to_payload(payload, share) if share[:url]
          return add_image_to_payload(payload, share) if share[:image]

          payload
        end

        def v2_request_image_upload_payload(urn)
          {
            registerUploadRequest: {
              recipes: [
                "urn:li:digitalmediaRecipe:feedshare-image"
              ],
              owner: "urn:li:person:#{urn}",
              serviceRelationships: [
                {
                  relationshipType: "OWNER",
                  identifier: "urn:li:userGeneratedContent"
                }
              ]
            }
          }
        end

        def add_image_to_payload(payload, share)
          media = { status: 'READY', media: share[:image] }
          if share[:description]
            media[:description] = { text: share[:description] }
          end
          if share[:title]
            media[:title] = { text: share[:title] }
          end

          payload[:specificContent]['com.linkedin.ugc.ShareContent'][:shareMediaCategory] = 'IMAGE'
          payload[:specificContent]['com.linkedin.ugc.ShareContent'][:media] = [media]

          payload
        end

        def add_url_to_payload(payload, share)
          media = { status: 'READY', originalUrl: share[:url] }
          if share[:description]
            media[:description] = { text: share[:description] }
          end
          if share[:title]
            media[:title] = { text: share[:title] }
          end

          payload[:specificContent]['com.linkedin.ugc.ShareContent'][:shareMediaCategory] = 'ARTICLE'
          payload[:specificContent]['com.linkedin.ugc.ShareContent'][:media] = [media]

          payload
        end
    end
  end
end
