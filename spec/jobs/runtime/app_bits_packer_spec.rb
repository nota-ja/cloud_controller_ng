require "spec_helper"

module VCAP::CloudController
  module Jobs::Runtime
    describe AppBitsPacker do
      let(:uploaded_path) { "tmp/uploaded.zip" }

      subject(:job) do
        AppBitsPacker.new("app_guid", uploaded_path, [:fingerprints])
      end

      describe "#perform" do
        let(:app) { double(:app) }
        let(:fingerprints) { double(:fingerprints) }
        let(:package_blobstore) { double(:package_blobstore) }
        let(:global_app_bits_cache) { double(:global_app_bits_cache) }
        let(:tmpdir) { "/tmp/special_temp" }
        let(:max_droplet_size) { 256 }

        before do
          config_override({:directories => {:tmpdir => tmpdir}, :packages => config[:packages].merge(:max_droplet_size => max_droplet_size)})

          FingerprintsCollection.stub(:new) { fingerprints }
          App.stub(:find) { app }
          AppBitsPackage.stub(:new) { double(:packer, create: "done") }
        end

        it "finds the app from the guid" do
          App.should_receive(:find).with(guid: "app_guid")
          job.perform
        end

        it "creates blob stores" do
          CloudController::DependencyLocator.instance.should_receive(:package_blobstore)
          CloudController::DependencyLocator.instance.should_receive(:global_app_bits_cache)
          job.perform
        end

        it "creates an app bit packer and performs" do
          CloudController::DependencyLocator.instance.should_receive(:package_blobstore).and_return(package_blobstore)
          CloudController::DependencyLocator.instance.should_receive(:global_app_bits_cache).and_return(global_app_bits_cache)

          packer = double
          AppBitsPackage.should_receive(:new).with(package_blobstore, global_app_bits_cache, max_droplet_size, tmpdir).and_return(packer)
          packer.should_receive(:create).with(app, uploaded_path, fingerprints)
          job.perform
        end

        it "times out if the job takes longer than its timeout" do
          CloudController::DependencyLocator.stub(:instance) do
            sleep 2
          end

          job.stub(:max_run_time).with(:app_bits_packer).and_return( 0.001 )

          expect {
            job.perform
          }.to raise_error(Timeout::Error)
        end
      end
    end
  end
end
