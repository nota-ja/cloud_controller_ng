require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe Stager do
      let(:messenger) { instance_double(Messenger, send_desire_request: nil) }
      let(:app) { AppFactory.make(staging_task_id: 'first_id') }
      let(:staging_config) { TestConfig.config[:stager] }

      let(:completion_handler) do
        instance_double(Diego::Traditional::StagingCompletionHandler, staging_complete: nil)
      end

      subject(:stager) do
        Stager.new(app, messenger, completion_handler, staging_config)
      end

      it_behaves_like 'a stager'

      describe '#stage_app' do
        before do
          allow(messenger).to receive(:send_stage_request)
          allow(messenger).to receive(:send_stop_staging_request)
        end

        it 'notifies Diego that the app needs staging' do
          expect(app).to receive(:mark_for_restaging)
          expect(messenger).to receive(:send_stage_request).with(app, staging_config)
          stager.stage_app
        end

        context 'when there is a pending stage' do
          it 'attempts to stop the outstanding stage request' do
            expect(messenger).to receive(:send_stop_staging_request).with(app)
            stager.stage_app
          end
        end
      end

      describe '#staging_complete' do
        let(:staging_guid) { 'a-staging-guid' }
        let(:staging_response) { { app_id: 'app-id' } }

        before do
          allow(completion_handler).to receive(:staging_complete)

          stager.staging_complete(staging_guid, staging_response)
        end

        it 'delegates to the staging completion handler' do
          expect(completion_handler).to have_received(:staging_complete).with(staging_guid, staging_response)
        end
      end
    end
  end
end
