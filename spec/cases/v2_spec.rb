require 'helper'

describe LinkedIn::Api::V2 do
  let(:token) { '77j2rfbjbmkcdh' }
  let(:consumer_options) do
    { site: 'https://api.linkedin.com', raise_errors: false }
  end

  let(:client) { LinkedIn::Client.new('token', 'secret') }
  let(:consumer) { OAuth2::Client.new('token', 'secret', consumer_options) }

  let(:headers) do
    {
      'Accept'=>'*/*',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization'=>"Bearer #{token}",
      'Content-Type' => 'application/json',
      'User-Agent'=>'Faraday v0.15.4',
      'X-Li-Format' => 'json',
      'X-Restli-Protocol-Version' => '2.0.0'
    }
  end

  before do
    LinkedIn.default_profile_fields = nil
    client.stub(:consumer).and_return(consumer)
    client.authorize_from_access(token)
  end

  describe '#v2_profile' do
    let(:api_url) { 'https://api.linkedin.com/v2/me' }

    context "when LinkedIn returns 201 status code" do
      before { stub_request(:get, api_url) }

      it "should send a request" do
        client.v2_profile

        expect(a_request(:get, api_url).with(headers: headers, body: nil)
        ).to have_been_made.once
      end
    end

    context 'when LinkedIn returns 403 status code' do
      before { stub_request(:get, api_url).to_return(body: '{}', status: 403) }

      it 'returns 403 status code' do
        expect do
          client.v2_profile
        end.to raise_error(LinkedIn::Errors::AccessDeniedError)
      end
    end
  end

  describe "#v2_request_image_upload_url" do
    let(:api_url) { 'https://api.linkedin.com/v2/assets?action=registerUpload' }
    let(:urn) { '1234567890' }
    let(:body) {
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
    }

    before { stub_request(:post, api_url).to_return(body: '{}', status: 201) }

    it "should send request" do
      client.v2_request_image_upload_url(urn)

      expect(a_request(:post, 'https://api.linkedin.com/v2/assets?action=registerUpload')
        .with(body: body, headers: headers)
      ).to have_been_made.once
    end
  end

  describe "#v2_upload_image" do
    let(:api_url) { "https://api.linkedin.com/mediaUpload/C5522AQGTYER3k3ByHQ/feedshare-uploadedImage/0?ca=vector_feedshare&cn=uploads&m=AQJbrN86Zm265gAAAWemyz2pxPSgONtBiZdchrgG872QltnfYjnMdb2j3A&app=1953784&sync=0&v=beta&ut=2H-IhpbfXrRow1" }
    let(:body) { "\xFF\xD8\xFF\xE0\u0000\u0010J" }

    let(:headers) do
      {
        'Accept'=>'*/*',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization'=>"Bearer #{token}",
        'Content-Type' => 'application/octet-stream',
        'User-Agent'=>'Faraday v0.15.4',
        'X-Li-Format' => 'json',
        'X-Restli-Protocol-Version' => '2.0.0'
      }
    end

    before { stub_request(:post, api_url).to_return(body: '{}', status: 201) }

    it "should send binay upload" do
      client.v2_upload_image(api_url, body)

      expect(a_request(:post, api_url)
        .with(body: body, headers: headers)
      ).to have_been_made.once
    end
  end

  describe '#v2_add_share' do
    let(:urn) { '1234567890' }
    let(:comment) { 'Testing, 1, 2, 3' }
    let(:url) { 'http://example.com/share' }
    let(:image) { 'urn:li:digitalmediaAsset:C4D22AQHdunx-1RlagQ' }
    let(:title) { 'Foobar Title' }
    let(:body) do
      { author: "urn:li:person:#{urn}", lifecycleState: 'PUBLISHED',
        visibility: { 'com.linkedin.ugc.MemberNetworkVisibility' => 'PUBLIC' } }
    end

    context "when comment, image, and title" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            shareCommentary: { text: comment },
            media: [
              { status: 'READY', media: image, title: { text: title } }
            ],
            shareMediaCategory: 'IMAGE'
          }
        }
        stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .to_return(body: '{}', status: 201)
      end

      it "should send a request" do
        client.v2_add_share(urn, comment: comment, image: image, title: title)

        expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .with(body: body, headers: headers)
        ).to have_been_made.once
      end
    end

    context "when image and comment" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            media: [{ status: 'READY', media: image }],
            shareCommentary: { text: comment },
            shareMediaCategory: 'IMAGE'
          }
        }
        stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .to_return(body: '{}', status: 201)
      end

      it "should send a request" do
        client.v2_add_share(urn, image: image, comment: comment)

        expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .with(body: body, headers: headers)
        ).to have_been_made.once
      end
    end

    context "when comment only" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            shareCommentary: { text: comment },
            shareMediaCategory: 'NONE'
          }
        }
      end

      context "when LinkedIn returns 201 status code" do
        before do
          stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
            .to_return(body: '{}', status: 201)
        end

        it "should send a request" do
          client.v2_add_share(urn, comment: comment)

          expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
            .with(body: body, headers: headers)
          ).to have_been_made.once
        end

        it "should send with different visibility" do
          body[:visibility]['com.linkedin.ugc.MemberNetworkVisibility'] = "CONNECTIONS"
          client.v2_add_share(urn, comment: comment, visibility: "CONNECTIONS")

          expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
            .with(body: body, headers: headers)
          ).to have_been_made.once
        end
      end

      context "when LinkedIn returns 403 status code" do
        before do
          stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
            .to_return(body: '{}', status: 403)
        end

        it "should raise AccessDeniedError" do
          expect do
            client.v2_add_share(urn, comment: comment)
          end.to raise_error(LinkedIn::Errors::AccessDeniedError)
        end
      end
    end

    context "when comment, url, and title" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            shareCommentary: { text: comment },
            media: [
              { status: 'READY', originalUrl: url, title: { text: title } }
            ],
            shareMediaCategory: 'ARTICLE'
          }
        }
        stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .to_return(body: '{}', status: 201)
      end

      it "should send a request" do
        client.v2_add_share(urn, comment: comment, url: url, title: title)

        expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .with(body: body, headers: headers)
        ).to have_been_made.once
      end
    end

    context "when url and comment" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            media: [{ status: 'READY', originalUrl: url }],
            shareCommentary: { text: comment },
            shareMediaCategory: 'ARTICLE'
          }
        }
        stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .to_return(body: '{}', status: 201)
      end

      it "should send a request" do
        client.v2_add_share(urn, url: url, comment: comment)

        expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .with(body: body, headers: headers)
        ).to have_been_made.once
      end
    end

    context "when comment and title" do
      before do
        body[:specificContent] = {
          'com.linkedin.ugc.ShareContent' => {
            shareCommentary: { text: comment },
            shareMediaCategory: 'NONE'
          }
        }

        stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .to_return(body: '{}', status: 201)
      end

      it "should send a request with comment only" do
        client.v2_add_share(urn, title: title, comment: comment)

        expect(a_request(:post, 'https://api.linkedin.com/v2/ugcPosts')
          .with(body: body, headers: headers)
        ).to have_been_made.once
      end
    end

    context "when url and title only" do
      before { stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts') }

      it "should raise error" do
        expect do
          client.v2_add_share(urn, url: url, title: title)
        end.to raise_error(LinkedIn::Errors::UnavailableError)
      end
    end

    context "when url only" do
      before { stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts') }

      it "should raise error" do
        expect do
          client.v2_add_share(urn, url: url)
        end.to raise_error(LinkedIn::Errors::UnavailableError)
      end
    end

    context "when title only" do
      before { stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts') }

      it "should raise error" do
        expect do
          client.v2_add_share(urn, title: title)
        end.to raise_error(LinkedIn::Errors::UnavailableError)
      end
    end

    context "when no urn" do
      before { stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts') }

      it "should raise error" do
        expect do
          client.v2_add_share(comment: comment)
        end.to raise_error(LinkedIn::Errors::UnavailableError)
      end
    end

    context "when urn is blank" do
      before { stub_request(:post, 'https://api.linkedin.com/v2/ugcPosts') }

      it "should raise error" do
        expect do
          client.v2_add_share('', comment: comment)
        end.to raise_error(LinkedIn::Errors::UnavailableError)
      end
    end
  end
end
