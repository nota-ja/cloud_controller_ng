require "spec_helper"
require "cloud_controller/safe_zipper"

describe SafeZipper do
  around do |example|
    Dir.mktmpdir("foo") do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  describe ".unzip" do
    let(:zip_path) { File.expand_path("../fixtures/good.zip", __FILE__) }
    let(:zip_destination) { @tmpdir }

    subject(:unzip) { SafeZipper.unzip(zip_path, zip_destination) }

    it "unzips the file given" do
      unzip
      expect(Dir["#{zip_destination}/**/*"].size).to eq 4
      expect(Dir["#{zip_destination}/*"].size).to eq 3
      expect(Dir["#{zip_destination}/subdir/*"].size).to eq 1
    end

    it "returns the size of the unzipped files" do
      expect(SafeZipper.unzip(zip_path, zip_destination)).to eq 17
    end

    it "returns the size if it is large" do
      Open3.stub(:capture3).with(%Q{unzip -l #{zip_path}}).and_return(
        [
          "\nArchive:\n Filename\n ---\n app.rb\n10000000001 1 file",
          nil,
          double("status", :success? => true)]
      )
      expect(SafeZipper.unzip(zip_path, zip_destination)).to eq 10000000001
    end

    context "when the zip_destination doesn't exist" do
      let(:zip_destination) { 'bar' }

      it "raises an exception" do
        expect { unzip }.to raise_exception VCAP::Errors::AppBitsUploadInvalid, /destination does not exist/i
      end
    end

    context "when the underlying unzip fails" do
      let(:zip_path) { File.expand_path("../fixtures/corrupt.zip")}

      it "raises an exception" do
        expect { unzip }.to raise_exception VCAP::Errors::AppBitsUploadInvalid, /unzipping had errors\n STDOUT: ""\n STDERR: "unzip:\s+cannot find or open/im
      end
    end

    context "when the zip is empty" do
      let(:zip_path) { File.expand_path("../fixtures/empty.zip", __FILE__) }

      it "raises an exception" do
        expect { unzip }.to raise_exception VCAP::Errors::AppBitsUploadInvalid, /unzipping had errors/i
      end
    end

    describe "symlinks" do
      context "when they are inside the root directory" do
        let(:zip_path) { File.expand_path("../fixtures/good_symlinks.zip", __FILE__) }

        it "unzips them archive correctly without errors" do
          unzip
          expect(File.symlink?("#{zip_destination}/what")).to be_true
        end
      end

      context "when the are outside the root directory" do
        let(:zip_path) { File.expand_path("../fixtures/bad_symlinks.zip", __FILE__) }

        it "raises an exception" do
          expect { unzip }.to raise_exception VCAP::Errors::AppBitsUploadInvalid, /symlink.+outside/i
        end
      end
    end

    describe "relative paths" do
      context "when the are inside the root directory" do
        let(:zip_path) { File.expand_path("../fixtures/good_relative_paths.zip", __FILE__) }

        it "unzips them archive correctly without errors" do
          unzip
          expect(File.exists?("#{zip_destination}/bar/../cat")).to be_true
        end
      end

      context "when the are outside the root directory" do
        let(:zip_path) { File.expand_path("../fixtures/bad_relative_paths.zip", __FILE__) }

        it "raises an exception" do
          expect { unzip }.to raise_exception VCAP::Errors::AppBitsUploadInvalid, /relative path.+outside/i
        end
      end
    end
  end

  describe ".zip" do
    let(:root_path) { File.expand_path("../fixtures/fake_package/", __FILE__) }
    let(:tmp_zip) { File.join(@tmpdir, "tmp.zip") }

    it "zips the file" do
      SafeZipper.zip(root_path, tmp_zip)

      output = `zipinfo #{tmp_zip}`
      expect(output).not_to include "./"
      expect(output).not_to include "spec/fixtures/fake_package"
      expect(output).to include "subdir/there"
      expect(output).to match %r{^l.+coming_from_inside$}
      expect(output).to include "4 files"
    end

    context "when the root path is empty" do
      let(:root_path) { File.expand_path("../fixtures/no_exist", __FILE__) }

      it "will raise an error" do
        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception VCAP::Errors::AppPackageInvalid, /path does not exist/i
      end
    end

    context "when the destination directory does not exist" do
      let(:tmp_zip) { "/non/existent/path/to/tmp.zip" }

      it "will raise an error" do
        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception VCAP::Errors::AppPackageInvalid, /path does not exist/i
      end
    end

    context "when the zipping fails" do
      let(:tmp_zip) { "/non/existent/path/to/tmp.zip" }

      it "will raise an error" do
        File.stub(:exists?).and_return(true)

        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception VCAP::Errors::AppPackageInvalid, /could not zip the package\n STDOUT: "zip .+?"\n STDERR: ""/im
      end
    end
  end
end